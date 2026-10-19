import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import '../models/borrow_request.dart';

/// Reads and writes `bookings`.
///
/// Approve, reject, release and return **do not update the row from the
/// client**. They call the Postgres functions, because each of those moves
/// several rows together and re-checks state inside a row lock:
///
/// * `approve_booking` takes `FOR UPDATE` on the booking and re-checks for
///   overlapping approved bookings before flipping the status, so two
///   approvers tapping Approve a second apart cannot both win;
/// * `release_asset` / `return_asset` write the `transactions` row and move
///   `bookings.status` and `assets.status` together, or not at all.
///
/// A plain client `update` would leave those rows inconsistent and would be
/// rejected anyway by `validate_booking_status_transition`.
class BorrowRepository {
  BorrowRepository(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  /// Joins the asset and the borrower so list rows can show names without an
  /// extra round trip each. The relation names follow Postgres' defaults for
  /// unnamed foreign keys: `bookings_asset_id_fkey`,
  /// `bookings_borrower_id_fkey`.
  static const String _selectFull =
      '*,asset:assets(*),requester:profiles!bookings_borrower_id_fkey(*),'
      'transaction:transactions(*)';

  // ---- Reads ---------------------------------------------------------------

  /// The signed-in person's own requests.
  Future<List<BorrowRequest>> fetchMyRequests({RequestStatus? status}) async {
    var query = _client
        .from('bookings')
        .select(_selectFull)
        .eq('borrower_id', _uid ?? '');

    if (status != null) {
      query = query.eq('status', status.value);
    }

    final data = await query.order('submitted_at', ascending: false);
    return _parse(data);
  }

  /// Finished requests — completed, declined or withdrawn.
  ///
  /// RLS decides the scope: a resident sees their own rows, an official sees
  /// every row. The screen therefore needs no role branch of its own.
  Future<List<BorrowRequest>> fetchHistory({int limit = 200}) async {
    final data = await _client
        .from('bookings')
        .select(_selectFull)
        .inFilter('status', [
          RequestStatus.completed.value,
          RequestStatus.rejected.value,
          RequestStatus.cancelled.value,
        ])
        .order('submitted_at', ascending: false)
        .limit(limit);
    return _parse(data);
  }

  /// The approvals queue: everything still waiting on a decision.
  Future<List<BorrowRequest>> fetchPendingReviews() async {
    final data = await _client
        .from('bookings')
        .select(_selectFull)
        .eq('status', RequestStatus.pending.value)
        .order('start_time', ascending: true);
    return _parse(data);
  }

  /// Approved and out — what staff monitor while an item is with a resident.
  Future<List<BorrowRequest>> fetchOngoingRequests() async {
    final data = await _client
        .from('bookings')
        .select(_selectFull)
        .inFilter('status', [
          RequestStatus.approved.value,
          RequestStatus.released.value,
          RequestStatus.overdue.value,
        ])
        .order('expected_return_time', ascending: true);
    return _parse(data);
  }

  Future<BorrowRequest?> fetchById(String id) async {
    final data = await _client
        .from('bookings')
        .select(_selectFull)
        .eq('id', id)
        .maybeSingle();
    return data == null ? null : BorrowRequest.fromMap(data);
  }

  /// Upcoming reservations, for the dashboard.
  Future<List<BorrowRequest>> fetchUpcoming({int limit = 5}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = await _client
        .from('bookings')
        .select(_selectFull)
        .inFilter('status', [
          RequestStatus.approved.value,
          RequestStatus.pending.value,
        ])
        .gte('end_time', now)
        .order('start_time')
        .limit(limit);
    return _parse(data);
  }

  /// Whether an asset is free for a window.
  ///
  /// Delegates to the same function `approve_booking` uses, so the answer
  /// shown in the form cannot disagree with the one an approver gets.
  Future<bool> isAssetAvailable({
    required String assetId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await _client.rpc(
      'check_asset_availability',
      params: {
        'p_asset_id': assetId,
        'p_start': from.toUtc().toIso8601String(),
        'p_end': to.toUtc().toIso8601String(),
      },
    );
    return result == true;
  }

  // ---- Writes --------------------------------------------------------------

  /// Files a new request.
  ///
  /// `status` is not sent: the column defaults to `pending` and the RLS insert
  /// policy requires it, so a modified client cannot file a self-approved
  /// request.
  Future<BorrowRequest> createRequest({
    required String assetId,
    required String purpose,
    required DateTime borrowDate,
    required DateTime returnDate,
    BookingType bookingType = BookingType.borrow,
    String? notes,
    String? authorizedDriverName,
    List<String> documentUrls = const [],
  }) async {
    final borrowerId = _uid;
    if (borrowerId == null) {
      throw const BorrowException('You need to sign in before making a request.');
    }

    if (!returnDate.isAfter(borrowDate)) {
      throw const BorrowException(
        'The return date must be after the borrow date.',
      );
    }

    // Insert, then read back through the same join every list uses. The
    // insert response cannot be relied on to embed `transactions` (there is
    // none yet), and re-reading keeps one parsing path for every screen.
    final inserted = await _client
        .from('bookings')
        .insert({
          'asset_id': assetId,
          'borrower_id': borrowerId,
          'booking_type': bookingType.value,
          'purpose': purpose.trim(),
          'start_time': borrowDate.toUtc().toIso8601String(),
          'end_time': returnDate.toUtc().toIso8601String(),
          'expected_return_time': returnDate.toUtc().toIso8601String(),
          'notes': notes,
          'authorized_driver_name': authorizedDriverName,
          'document_urls': documentUrls,
        })
        .select('id')
        .single();

    final created = await fetchById(inserted['id'] as String);
    if (created == null) {
      throw const BorrowException(
        'The request was saved but could not be read back.',
      );
    }
    return created;
  }

  /// Approves a request.
  ///
  /// The database re-checks the schedule inside the transaction, so if the slot
  /// was taken while this request sat in the queue this throws with the
  /// database's own message ("This asset is already reserved for that time.")
  /// rather than double-booking it.
  Future<BorrowRequest> approve({required String id, String? remarks}) async {
    await _client.rpc(
      'approve_booking',
      params: {'p_booking_id': id, 'p_reason': remarks},
    );
    final updated = await fetchById(id);
    if (updated == null) {
      throw const BorrowException('The request could not be read back.');
    }
    return updated;
  }

  /// Rejects a request. A reason is required by the schema: a rejection a
  /// resident cannot understand is not a decision, it is a dismissal.
  Future<BorrowRequest> reject({
    required String id,
    required String remarks,
  }) async {
    if (remarks.trim().isEmpty) {
      throw const BorrowException('Please give a reason for the rejection.');
    }
    await _client.rpc(
      'reject_booking',
      params: {'p_booking_id': id, 'p_reason': remarks.trim()},
    );
    final updated = await fetchById(id);
    if (updated == null) {
      throw const BorrowException('The request could not be read back.');
    }
    return updated;
  }

  /// Hands an approved asset over to its borrower.
  Future<void> release({
    required String id,
    required AssetCondition initialCondition,
    List<String> includedItems = const [],
    String? notes,
  }) async {
    await _client.rpc(
      'release_asset',
      params: {
        'p_booking_id': id,
        'p_initial_condition': initialCondition.value,
        'p_included_items': includedItems,
        'p_notes': notes,
      },
    );
  }

  /// Records an asset coming back.
  ///
  /// `return_asset` sets the transaction's inspection flag itself when the
  /// reported condition is damage or missing items, so the follow-up belongs
  /// to the record rather than to whichever screen happened to be open.
  Future<void> markReturned({
    required String id,
    required AssetCondition condition,
    String? remarks,
    String? missingItems,
    List<String> photoUrls = const [],
  }) async {
    await _client.rpc(
      'return_asset',
      params: {
        'p_booking_id': id,
        'p_return_condition': condition.value,
        'p_damage_notes': remarks,
        'p_missing_items': missingItems,
        'p_photo_urls': photoUrls,
      },
    );
  }

  /// Withdraws a request. Allowed for the borrower while it has not been
  /// handed over; the RLS update policy and the status-transition trigger
  /// enforce that again on the server.
  Future<BorrowRequest> cancel(String id, {String? remarks}) async {
    await _client.from('bookings').update({
      'status': RequestStatus.cancelled.value,
      'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      'rejection_reason': remarks,
    }).eq('id', id);

    final updated = await fetchById(id);
    if (updated == null) {
      throw const BorrowException(
        'The request was withdrawn but could not be read back.',
      );
    }
    return updated;
  }

  /// Sweeps past-due items into `overdue`.
  ///
  /// Returns the number of rows changed, so the caller can tell whether the
  /// list it is showing is stale.
  Future<int> refreshOverdue() async {
    final result = await _client.rpc('mark_overdue_bookings');
    return (result as int?) ?? 0;
  }

  // ---- Helpers -------------------------------------------------------------

  List<BorrowRequest> _parse(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => BorrowRequest.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }
}

/// A failure the screens can show verbatim.
///
/// The database writes its `RAISE` messages to be read by a barangay official
/// ("This asset is already reserved for that time."), so those are surfaced as
/// they are rather than replaced with something generic.
class BorrowException implements Exception {
  const BorrowException(this.message);

  final String message;

  @override
  String toString() => message;
}