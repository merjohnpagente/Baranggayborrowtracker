import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import '../models/booking.dart';
import '../services/supabase_service.dart';
import '../utils/booking_rules.dart';
import 'result.dart';

/// Reads and writes `bookings`.
///
/// The two approval operations deliberately do **not** update the row from the
/// client. They call the `approve_booking` / `reject_booking` Postgres
/// functions, which take a row lock and re-check for schedule conflicts inside
/// the transaction. Two approvers tapping "Approve" a second apart therefore
/// cannot both win — which is business rules 5 and 16, enforced where it has to
/// be rather than hoped for in the UI.
class BookingRepository {
  const BookingRepository();

  SupabaseClient get _client => SupabaseService.client;

  String? get _uid => SupabaseService.currentUserId;

  /// Bookings for one borrower, newest first.
  Future<Result<List<Booking>>> forBorrower(String borrowerId) async {
    try {
      final data = await _client
          .from('bookings')
          .select('''
            *,
            assets ( name, asset_code ),
            profiles!bookings_borrower_id_fkey ( full_name, phone_number )
          ''')
          .eq('borrower_id', borrowerId)
          .order('submitted_at', ascending: false);
      return Result.success(_rows(data).map(_flatten).toList());
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Pending requests awaiting a decision, for approvers and staff.
  Future<Result<List<Booking>>> pendingRequests() async {
    try {
      final data = await _client
          .from('bookings')
          .select('''
            *,
            assets ( name, asset_code ),
            profiles!bookings_borrower_id_fkey ( full_name, phone_number )
          ''')
          .eq('status', BookingStatus.pending.wire)
          .order('submitted_at', ascending: false);
      return Result.success(_rows(data).map(_flatten).toList());
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Every booking in a window, for the history and reports screens.
  Future<Result<List<Booking>>> inRange({
    DateTime? from,
    DateTime? to,
    BookingStatus? status,
  }) async {
    try {
      var query = _client.from('bookings').select('''
            *,
            assets ( name, asset_code ),
            profiles!bookings_borrower_id_fkey ( full_name, phone_number )
          ''');
      if (from != null) query = query.gte('start_time', from.toIso8601String());
      if (to != null) query = query.lte('start_time', to.toIso8601String());
      if (status != null) query = query.eq('status', status.wire);
      final data = await query.order('start_time', ascending: false);
      return Result.success(_rows(data).map(_flatten).toList());
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  Future<Result<Booking>> byId(String id) async {
    try {
      final data = await _client
          .from('bookings')
          .select('''
            *,
            assets ( name, asset_code ),
            profiles!bookings_borrower_id_fkey ( full_name, phone_number )
          ''')
          .eq('id', id)
          .maybeSingle();
      if (data == null) return const Failure('That request no longer exists.');
      return Success(_flatten(data));
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Approved bookings for one asset that overlap [start]..[end].
  ///
  /// Used by the booking form to warn before submission. The database re-runs
  /// this inside `approve_booking`, because a warning shown now can be stale by
  /// the time somebody approves it.
  Future<Result<List<Booking>>> conflictsFor({
    required String assetId,
    required DateTime start,
    required DateTime end,
    String? ignoreBookingId,
  }) async {
    try {
      final data = await _client
          .from('bookings')
          .select('*, assets ( name, asset_code )')
          .eq('asset_id', assetId)
          .in('status', [
            BookingStatus.approved.wire,
            BookingStatus.released.wire,
            BookingStatus.overdue.wire,
          ])
          // Half-open overlap: `existing.start < newEnd AND existing.end > newStart`.
          .lt('start_time', end.toIso8601String())
          .gt('end_time', start.toIso8601String());

      final bookings = _rows(data).map(_flatten).toList();
      if (ignoreBookingId != null) {
        return Success(
          bookings.where((b) => b.id != ignoreBookingId).toList(),
        );
      }
      return Success(bookings);
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Files a new request.
  ///
  /// Three guards run before the insert, in order of how expensive they are to
  /// get wrong:
  ///   1. the date range is not inverted (rule 2);
  ///   2. the asset is still reservable — not archived, not in maintenance
  ///      (rule 1);
  ///   3. no already-approved booking overlaps the window (rule 3).
  ///
  /// A near-identical pending request from the same borrower for the same
  /// window is refused rather than duplicated (rule 15), which is what a
  /// double-tapped Submit button actually looks like.
  Future<Result<Booking>> create({
    required Asset asset,
    required String purpose,
    required DateTime start,
    required DateTime end,
    required DateTime expectedReturn,
    String? authorizedDriverName,
    String? notes,
    List<String> documentUrls = const [],
  }) async {
    final borrowerId = _uid;
    if (borrowerId == null) {
      return const Failure('You need to sign in before making a request.');
    }

    if (!BookingRules.isValidRange(start, end)) {
      return const Failure('The end time must be after the start time.');
    }

    if (!BookingRules.isAssetEligible(
      statusCanBeRequested: asset.status.canBeRequested,
      isArchived: asset.isArchived,
      quantity: asset.quantity,
    )) {
      return Failure(
        asset.isArchived
            ? 'That asset has been archived and cannot be requested.'
            : 'That asset is currently ${asset.status.label.toLowerCase()} '
                'and cannot be requested.',
      );
    }

    try {
      // Duplicate-submission check, scoped to this borrower and this window.
      final recent = await _client
          .from('bookings')
          .select('*, assets ( name, asset_code )')
          .eq('borrower_id', borrowerId)
          .eq('asset_id', asset.id)
          .eq('start_time', start.toIso8601String())
          .eq('end_time', end.toIso8601String())
          .in('status', ['pending', 'approved'])
          .limit(1);

      if (_rows(recent).isNotEmpty) {
        return const Failure(
          'You already have a request for that asset at that time.',
        );
      }

      final conflict = await conflictsFor(
        assetId: asset.id,
        start: start,
        end: end,
      );
      final conflicts = conflict.valueOrNull ?? const <Booking>[];
      if (BookingRules.hasConflict(
        Booking(
          id: '',
          requestId: '',
          assetId: asset.id,
          borrowerId: borrowerId,
          purpose: purpose,
          startTime: start,
          endTime: end,
          expectedReturnTime: expectedReturn,
          submittedAt: DateTime.now(),
        ),
        conflicts,
      )) {
        final clash = conflicts.first;
        return Failure(
          'That slot is already taken by request ${clash.requestId}.',
        );
      }

      final payload = {
        'asset_id': asset.id,
        'borrower_id': borrowerId,
        'booking_type': asset.isBookableInPlace
            ? BookingType.reservation.wire
            : BookingType.borrow.wire,
        'purpose': purpose.trim(),
        'start_time': start.toUtc().toIso8601String(),
        'end_time': end.toUtc().toIso8601String(),
        'expected_return_time': expectedReturn.toUtc().toIso8601String(),
        'authorized_driver_name':
            authorizedDriverName?.trim().isEmpty ?? true
                ? null
                : authorizedDriverName!.trim(),
        'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
        'document_urls': documentUrls,
        // Status is not sent: the column default is `pending` and the RLS
        // insert policy requires it, so a client cannot file a self-approved
        // request even if it were modified to try.
      };

      final data = await _client
          .from('bookings')
          .insert(payload)
          .select('*, assets ( name, asset_code )')
          .single();

      return Success(_flatten(data));
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Approves a request through the database function.
  ///
  /// The conflict re-check and the status write happen in one transaction
  /// under a row lock, so this is safe to call from two devices at once.
  Future<Result<void>> approve(String bookingId) async {
    try {
      await _client.rpc('approve_booking', params: {'p_booking_id': bookingId});
      return const Success(null);
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Rejects a request. [reason] is required by the schema, because a
  /// rejection a resident cannot understand is not a decision, it is a
  /// dismissal.
  Future<Result<void>> reject(String bookingId, String reason) async {
    if (reason.trim().isEmpty) {
      return const Failure('Please give a reason for the rejection.');
    }
    try {
      await _client.rpc(
        'reject_booking',
        params: {'p_booking_id': bookingId, 'p_reason': reason.trim()},
      );
      return const Success(null);
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Withdraws a request. Allowed for the borrower while it has not been
  /// handed over, and enforced again by the RLS update policy.
  Future<Result<void>> cancel(String bookingId) async {
    try {
      final data = await _client
          .from('bookings')
          .update({
            'status': BookingStatus.cancelled.wire,
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
            'cancelled_by': _uid,
          })
          .eq('id', bookingId)
          .select('id, status')
          .single();

      final status = data['status'] as String?;
      if (status != BookingStatus.cancelled.wire) {
        return const Failure('That request can no longer be withdrawn.');
      }
      return const Success(null);
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Flattens the joined `assets` / `profiles` objects onto the booking row.
  ///
  /// PostgREST returns related rows as a nested object (or a list, for a
  /// one-to-many). Handling both shapes here means no screen has to know which
  /// side of the join produced which container.
  static Booking _flatten(Map<String, dynamic> row) {
    final asset = _first(row['assets']);
    final profile = _first(row['profiles']);
    return Booking.fromMap({
      ...row,
      'asset_name': asset?['name'],
      'asset_code': asset?['asset_code'],
      'borrower_name': profile?['full_name'],
      'borrower_phone': profile?['phone_number'],
    });
  }

  /// PostgREST wraps a to-one embed in a list; take the first row if so.
  static Map<String, dynamic>? _first(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  static List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) {
      return data
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }
}