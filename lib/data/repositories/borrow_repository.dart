import '../local/ids.dart';
import '../local/local_store.dart';
import '../models/asset.dart';
import '../models/borrow_request.dart';
import '../models/user_profile.dart';

/// Reads and writes bookings, with the workflow rules in Dart.
///
/// These rules used to live in Postgres functions (`approve_booking`,
/// `release_asset`, `return_asset`, `mark_overdue_bookings`). Since the app is
/// now standalone, the same invariants are enforced here:
///
/// * only an admin/approver may approve or reject;
/// * approval re-checks the window, so two pending requests for the same slot
///   cannot both become approved;
/// * release and return move the booking, the asset and the custody record
///   together;
/// * statuses only move along [RequestStatus.transitionsTo].
///
/// The check is no longer a security boundary — a modified client can edit its
/// own JSON file — but it is the business logic the UI and reports rely on.
class BorrowRepository {
  BorrowRepository(this._store);

  final LocalStore _store;

  String? get _uid => _store.sessionUserId;

  // ---- Reads ---------------------------------------------------------------

  /// The signed-in person's own requests.
  Future<List<BorrowRequest>> fetchMyRequests({RequestStatus? status}) async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = _store.bookings
        .where((row) =>
            row['borrower_id'] == uid &&
            (status == null || row['status'] == status.value))
        .toList()
      ..sort((a, b) =>
          '${b['submitted_at']}'.compareTo('${a['submitted_at']}'));
    return _parse(rows);
  }

  /// Finished requests — completed, declined or withdrawn.
  ///
  /// A resident sees only their own history; an official sees every row, which
  /// is the same scope the RLS policies used to give them.
  Future<List<BorrowRequest>> fetchHistory({int limit = 200}) async {
    final me = _store.currentProfile;
    final isOfficer =
        me != null && UserRole.fromValue(me['role'] as String?).isOfficer;
    final uid = _uid;

    final rows = _store.bookings.where((row) {
      if (!const {'completed', 'rejected', 'cancelled'}
          .contains(row['status'])) {
        return false;
      }
      if (isOfficer) return true;
      return row['borrower_id'] == uid;
    }).toList()
      ..sort((a, b) =>
          '${b['submitted_at']}'.compareTo('${a['submitted_at']}'));

    return _parse(rows.take(limit));
  }

  /// The approvals queue: everything still waiting on a decision.
  Future<List<BorrowRequest>> fetchPendingReviews() async {
    final rows = _store.bookings
        .where((row) => row['status'] == RequestStatus.pending.value)
        .toList()
      ..sort((a, b) => '${a['start_time']}'.compareTo('${b['start_time']}'));
    return _parse(rows);
  }

  /// Approved and out — what staff monitor while an item is with a resident.
  Future<List<BorrowRequest>> fetchOngoingRequests() async {
    final rows = _store.bookings
        .where((row) => const {
              'approved',
              'released',
              'overdue',
            }.contains(row['status']))
        .toList()
      ..sort((a, b) => '${a['expected_return_time']}'
          .compareTo('${b['expected_return_time']}'));
    return _parse(rows);
  }

  Future<BorrowRequest?> fetchById(String id) async {
    final row = _store.bookingById(id);
    return row == null ? null : BorrowRequest.fromMap(_present(row));
  }

  /// Upcoming reservations, for the dashboard.
  Future<List<BorrowRequest>> fetchUpcoming({int limit = 5}) async {
    final now = DateTime.now();
    final rows = _store.bookings.where((row) {
      if (row['status'] != 'approved' && row['status'] != 'pending') {
        return false;
      }
      final end = _date(row['end_time']);
      return end.isAfter(now);
    }).toList()
      ..sort((a, b) => '${a['start_time']}'.compareTo('${b['start_time']}'));
    return _parse(rows.take(limit));
  }

  /// Whether an asset is free for a window.
  Future<bool> isAssetAvailable({
    required String assetId,
    required DateTime from,
    required DateTime to,
  }) async {
    return _store.isAssetAvailable(assetId, from, to);
  }

  // ---- Writes --------------------------------------------------------------

  /// Files a new request.
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
    final me = _requireUser();
    final uid = me['id'] as String;

    if (!returnDate.isAfter(borrowDate)) {
      throw const BorrowException(
        'The return date must be after the borrow date.',
      );
    }

    final asset = _store.assetById(assetId);
    if (asset == null || asset['archived_at'] != null) {
      throw const BorrowException('That asset is no longer available.');
    }
    if (asset['status'] != AssetStatus.available.value) {
      throw const BorrowException(
        'This asset is not available for new requests right now.',
      );
    }
    if (!_store.isAssetAvailable(assetId, borrowDate, returnDate)) {
      throw const BorrowException(
        'This asset is already reserved for that time.',
      );
    }

    final id = newLocalId();
    final reference = _store.newRequestId();
    final row = <String, dynamic>{
      'id': id,
      'request_id': reference,
      'asset_id': assetId,
      'borrower_id': uid,
      'booking_type': bookingType.value,
      'purpose': purpose.trim(),
      'start_time': _iso(borrowDate),
      'end_time': _iso(returnDate),
      'expected_return_time': _iso(returnDate),
      'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      'authorized_driver_id': null,
      'authorized_driver_name': authorizedDriverName?.trim(),
      'approved_by': null,
      'approved_at': null,
      'rejection_reason': null,
      'released_at': null,
      'returned_at': null,
      'cancelled_at': null,
      'cancelled_by': null,
      'document_urls': documentUrls,
      'status': RequestStatus.pending.value,
      'submitted_at': _store.nowIso(),
    };
    _store.bookings.add(row);

    // Tell the approval officers, then acknowledge the applicant, matching the
    // old `notify_staff_of_pending_request` trigger.
    for (final profile in _store.profiles) {
      final role = UserRole.fromValue(profile['role'] as String?);
      if (!role.canApprove) continue;
      if (profile['account_status'] != 'active') continue;
      if (profile['id'] == uid) continue;
      _store.addNotification(
        recipientId: profile['id'] as String,
        title: 'New request $reference',
        message: row['purpose'] as String?,
        type: 'request_submitted',
        relatedRecordId: id,
      );
    }
    _store.addNotification(
      recipientId: uid,
      title: 'Request received — $reference',
      message: 'Your request has been submitted and is waiting for review.',
      type: 'request_submitted',
      relatedRecordId: id,
    );

    await _store.save();
    return (await fetchById(id))!;
  }

  /// Approves a request, re-checking the schedule first.
  Future<BorrowRequest> approve({
    required String id,
    String? remarks,
  }) async {
    final me = _requireUser();
    if (!UserRole.fromValue(me['role'] as String?).canApprove) {
      throw const BorrowException(
        'Only an approver or an administrator can approve a request.',
      );
    }

    final booking = _store.bookingById(id);
    if (booking == null) {
      throw const BorrowException('Request not found.');
    }
    if (booking['status'] != RequestStatus.pending.value) {
      throw BorrowException(
        'This request is already ${booking['status']} and can no longer be '
        'approved.',
      );
    }

    final start = _date(booking['start_time']);
    final end = _date(booking['end_time']);
    if (!_store.isAssetAvailable(
      booking['asset_id'] as String,
      start,
      end,
      exceptBookingId: id,
    )) {
      throw const BorrowException(
        'This asset is already reserved for that time.',
      );
    }

    final note = remarks?.trim() ?? '';
    booking['status'] = RequestStatus.approved.value;
    booking['approved_by'] = me['id'];
    booking['approved_at'] = _store.nowIso();
    // Like the old function: an officer's note fills a blank, it never
    // overwrites what the resident wrote.
    if (((booking['notes'] as String?) ?? '').trim().isEmpty && note.isNotEmpty) {
      booking['notes'] = note;
    }

    _store.refreshAssetStatus(booking['asset_id'] as String);

    final reference = booking['request_id'] as String? ?? '';
    _store.addNotification(
      recipientId: booking['borrower_id'] as String,
      title: 'Approved — $reference',
      message: note.isEmpty
          ? 'Your request was approved. See you at the release counter.'
          : 'Your request was approved. $note',
      type: 'request_approved',
      relatedRecordId: id,
    );

    await _store.save();
    return (await fetchById(id))!;
  }

  /// Rejects a request. A reason is required: a rejection the resident cannot
  /// understand is not a decision.
  Future<BorrowRequest> reject({
    required String id,
    required String remarks,
  }) async {
    final me = _requireUser();
    if (!UserRole.fromValue(me['role'] as String?).canApprove) {
      throw const BorrowException(
        'Only an approver or an administrator can reject a request.',
      );
    }
    final reason = remarks.trim();
    if (reason.isEmpty) {
      throw const BorrowException(
        'Please give a reason for the rejection.',
      );
    }

    final booking = _store.bookingById(id);
    if (booking == null) {
      throw const BorrowException('Request not found.');
    }
    if (booking['status'] != RequestStatus.pending.value) {
      throw BorrowException(
        'This request is already ${booking['status']} and can no longer be '
        'rejected.',
      );
    }

    booking['status'] = RequestStatus.rejected.value;
    booking['rejection_reason'] = reason;
    booking['approved_by'] = me['id'];
    booking['approved_at'] = _store.nowIso();

    _store.refreshAssetStatus(booking['asset_id'] as String);

    _store.addNotification(
      recipientId: booking['borrower_id'] as String,
      title: 'Not approved — ${booking['request_id']}',
      message: reason,
      type: 'request_rejected',
      relatedRecordId: id,
    );

    await _store.save();
    return (await fetchById(id))!;
  }

  /// Hands an approved asset over to its borrower.
  Future<void> release({
    required String id,
    required AssetCondition initialCondition,
    List<String> includedItems = const [],
    String? notes,
  }) async {
    final me = _requireUser();
    if (!UserRole.fromValue(me['role'] as String?).canHandleAssets) {
      throw const BorrowException(
        'Only a staff member or an administrator can release an asset.',
      );
    }

    final booking = _store.bookingById(id);
    if (booking == null) {
      throw const BorrowException('Request not found.');
    }
    if (booking['status'] != RequestStatus.approved.value) {
      throw BorrowException(
        'Only an approved request can be released (this one is '
        '${booking['status']}).',
      );
    }

    final now = _store.nowIso();
    _store.transactions.add({
      'id': newLocalId(),
      'booking_id': id,
      'asset_id': booking['asset_id'],
      'borrower_id': booking['borrower_id'],
      'released_by': me['id'],
      'released_at': now,
      'initial_condition': initialCondition.value,
      'initial_notes': notes,
      'included_items': includedItems,
      'release_photo_urls': <String>[],
      'returned_to': null,
      'returned_at': null,
      'return_condition': null,
      'damage_notes': null,
      'missing_items': null,
      'return_notes': null,
      'return_photo_urls': <String>[],
      'return_status': 'open',
      'flagged_for_inspection': false,
      'created_at': now,
    });

    booking['status'] = RequestStatus.released.value;
    booking['released_at'] = now;
    _store.refreshAssetStatus(booking['asset_id'] as String);

    await _store.save();
  }

  /// Records an asset coming back.
  Future<void> markReturned({
    required String id,
    required AssetCondition condition,
    String? remarks,
    String? missingItems,
    List<String> photoUrls = const [],
  }) async {
    final me = _requireUser();
    if (!UserRole.fromValue(me['role'] as String?).canHandleAssets) {
      throw const BorrowException(
        'Only a staff member or an administrator can receive a returned '
        'asset.',
      );
    }

    final booking = _store.bookingById(id);
    if (booking == null) {
      throw const BorrowException('Request not found.');
    }
    final status = booking['status'];
    if (status != RequestStatus.released.value &&
        status != RequestStatus.overdue.value) {
      throw BorrowException(
        'This asset is not out (the request is $status).',
      );
    }

    final transaction = _store.transactionForBooking(id);
    if (transaction == null) {
      throw const BorrowException(
        'No custody record found for this request. Release it before '
        'recording a return.',
      );
    }

    final flagged = condition.needsInspection;
    final now = _store.nowIso();
    transaction['returned_to'] = me['id'];
    transaction['returned_at'] = now;
    transaction['return_condition'] = condition.value;
    transaction['damage_notes'] = remarks;
    transaction['missing_items'] = missingItems;
    transaction['return_notes'] = null;
    transaction['return_photo_urls'] = photoUrls;
    transaction['return_status'] = flagged ? 'flagged' : 'closed';
    transaction['flagged_for_inspection'] = flagged;

    booking['returned_at'] = now;
    booking['status'] = RequestStatus.completed.value;

    final asset = _store.assetById(booking['asset_id'] as String);
    if (asset != null) {
      asset['condition'] = condition.value;
      asset['updated_at'] = now;
    }
    _store.refreshAssetStatus(booking['asset_id'] as String);

    await _store.save();
  }

  /// Withdraws a request. Allowed for the borrower while it has not been handed
  /// over, and for an administrator.
  Future<BorrowRequest> cancel(String id, {String? remarks}) async {
    final me = _requireUser();
    final booking = _store.bookingById(id);
    if (booking == null) {
      throw const BorrowException('Request not found.');
    }

    final isOwner = booking['borrower_id'] == me['id'];
    final isAdmin = UserRole.fromValue(me['role'] as String?).canManageUsers;
    if (!isOwner && !isAdmin) {
      throw const BorrowException('You can only withdraw your own request.');
    }

    final status = booking['status'];
    if (status != RequestStatus.pending.value &&
        status != RequestStatus.approved.value) {
      throw BorrowException(
        'A request that is $status can no longer be withdrawn.',
      );
    }

    booking['status'] = RequestStatus.cancelled.value;
    booking['cancelled_at'] = _store.nowIso();
    booking['cancelled_by'] = me['id'];
    if (remarks != null && remarks.trim().isNotEmpty) {
      booking['rejection_reason'] = remarks.trim();
    }

    _store.refreshAssetStatus(booking['asset_id'] as String);
    await _store.save();
    return (await fetchById(id))!;
  }

  /// Sweeps past-due items into `overdue` and notifies the borrowers.
  ///
  /// Returns the number of rows changed so the caller can tell whether the
  /// list it is showing is stale.
  Future<int> refreshOverdue() async {
    final now = DateTime.now();
    var changed = 0;

    for (final booking in _store.bookings) {
      if (booking['status'] != RequestStatus.released.value) continue;
      final due = DateTime.tryParse('${booking['expected_return_time']}');
      if (due == null || !due.isBefore(now)) continue;

      booking['status'] = RequestStatus.overdue.value;
      changed++;
      _store.refreshAssetStatus(booking['asset_id'] as String);

      final borrowerId = booking['borrower_id'] as String?;
      if (borrowerId != null) {
        final reference = booking['request_id'] as String? ?? '';
        _store.addNotification(
          recipientId: borrowerId,
          title: 'Overdue — $reference',
          message: 'The asset borrowed under $reference is past its expected '
              'return time. Please return it at the barangay hall.',
          type: 'overdue_return',
          relatedRecordId: booking['id'] as String,
        );
      }
    }

    if (changed > 0) await _store.save();
    return changed;
  }

  // ---- Helpers -------------------------------------------------------------

  Map<String, dynamic> _requireUser() {
    final row = _store.currentProfile;
    if (row == null) {
      throw const BorrowException('You need to sign in first.');
    }
    return row;
  }

  /// Adds the embedded asset, requester and custody record that the screens
  /// expect, without a server-side join.
  Map<String, dynamic> _present(Map<String, dynamic> booking) {
    final map = Map<String, dynamic>.from(booking);
    final asset = _store.assetById(booking['asset_id'] as String?);
    if (asset != null) map['asset'] = asset;
    final requester = _store.profileById(booking['borrower_id'] as String?);
    if (requester != null) map['requester'] = requester;
    final transaction = _store.transactionForBooking(booking['id'] as String?);
    if (transaction != null) map['transaction'] = transaction;
    return map;
  }

  List<BorrowRequest> _parse(Iterable<Map<String, dynamic>> rows) =>
      rows.map((row) => BorrowRequest.fromMap(_present(row))).toList();

  static DateTime _date(Object? value) =>
      DateTime.tryParse('$value') ?? DateTime.now();

  static String _iso(DateTime value) => value.toUtc().toIso8601String();
}

/// A failure the screens can show verbatim.
class BorrowException implements Exception {
  const BorrowException(this.message);

  final String message;

  @override
  String toString() => message;
}
