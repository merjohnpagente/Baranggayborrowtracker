import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import '../models/booking.dart';
import '../models/notification.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';
import 'result.dart';

/// Release, return, history and notifications.
///
/// Release and return both go through Postgres functions rather than a pair of
/// updates. That matters for two reasons: the booking status, the asset status
/// and the transaction row must move together or not at all (rule 8), and the
/// write has to be attributable to the signed-in officer for the audit trail
/// (rule 11) — which only the database can know for sure.
class TransactionRepository {
  const TransactionRepository();

  SupabaseClient get _client => SupabaseService.client;

  /// Hands an approved asset over to its borrower.
  Future<Result<AssetTransaction>> release({
    required String bookingId,
    required AssetCondition initialCondition,
    List<String> includedItems = const [],
    String? notes,
  }) async {
    try {
      final data = await _client.rpc(
        'release_asset',
        params: {
          'p_booking_id': bookingId,
          'p_initial_condition': initialCondition.wire,
          'p_included_items': includedItems,
          'p_notes': notes,
        },
      );
      final row = _firstMap(data);
      if (row == null) return const Failure('The release was not recorded.');
      return Success(AssetTransaction.fromMap(row));
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Records an asset coming back.
  ///
  /// Any condition other than `good`/`serviceable` sets the transaction's
  /// `flagged_for_inspection` flag inside the function, so the follow-up is a
  /// property of the record rather than something a screen has to remember to
  /// do.
  Future<Result<AssetTransaction>> returnAsset({
    required String bookingId,
    required AssetCondition returnCondition,
    String? damageNotes,
    String? missingItems,
    String? notes,
    List<String> photoUrls = const [],
  }) async {
    try {
      final data = await _client.rpc(
        'return_asset',
        params: {
          'p_booking_id': bookingId,
          'p_return_condition': returnCondition.wire,
          'p_damage_notes': damageNotes,
          'p_missing_items': missingItems,
          'p_notes': notes,
          'p_photo_urls': photoUrls,
        },
      );
      final row = _firstMap(data);
      if (row == null) return const Failure('The return was not recorded.');
      return Success(AssetTransaction.fromMap(row));
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Transactions still open, i.e. the asset has not come back yet.
  Future<Result<List<AssetTransaction>>> active() async {
    try {
      final data = await _client
          .from('transactions')
          .select('''
            *,
            assets ( name, asset_code ),
            profiles!transactions_borrower_id_fkey ( full_name ),
            bookings ( request_id, expected_return_time )
          ''')
          .isFilter('returned_at', 'is', null)
          .order('released_at', ascending: false);
      return Result.success(_rows(data).map(_flatten).toList());
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Completed and open transactions, for the borrowing-history screen.
  Future<Result<List<AssetTransaction>>> history({int limit = 200}) async {
    try {
      final data = await _client
          .from('transactions')
          .select('''
            *,
            assets ( name, asset_code ),
            profiles!transactions_borrower_id_fkey ( full_name ),
            bookings ( request_id, expected_return_time )
          ''')
          .order('released_at', ascending: false)
          .limit(limit);
      return Result.success(_rows(data).map(_flatten).toList());
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  Future<Result<List<AssetTransaction>>> flaggedForInspection() async {
    try {
      final data = await _client
          .from('transactions')
          .select('''
            *,
            assets ( name, asset_code ),
            profiles!transactions_borrower_id_fkey ( full_name ),
            bookings ( request_id, expected_return_time )
          ''')
          .eq('flagged_for_inspection', true)
          .order('returned_at', ascending: false);
      return Result.success(_rows(data).map(_flatten).toList());
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  Future<Result<DashboardStats>> dashboardSummary() async {
    try {
      final data = await _client.rpc('dashboard_summary');
      final rows = _rows(data);
      if (rows.isEmpty) return const Success(DashboardStats.empty);
      final r = rows.first;
      return Success(
        DashboardStats(
          totalAssets: _int(r['total_assets']),
          availableAssets: _int(r['available_assets']),
          borrowedAssets: _int(r['borrowed_assets']),
          pendingRequests: _int(r['pending_requests']),
          overdueReturns: _int(r['overdue_returns']),
          upcomingReservations: _int(r['upcoming_reservations']),
          activeMaintenance: _int(r['active_maintenance']),
        ),
      );
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Notifications for the signed-in user.
  ///
  /// The `.eq('recipient_id', uid)` is a statement of intent; the RLS policy
  /// is what actually prevents one resident reading another's messages.
  Future<Result<List<AppNotification>>> notifications() async {
    try {
      final data = await _client
          .from('notifications')
          .select()
          .eq('recipient_id', SupabaseService.currentUserId ?? '')
          .order('created_at', ascending: false)
          .limit(100);
      return Result.success(
        _rows(data).map(AppNotification.fromMap).toList(),
      );
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  Future<Result<void>> markNotificationRead(String id) async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('recipient_id', SupabaseService.currentUserId ?? '');
      return const Success(null);
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  Future<Result<void>> markAllNotificationsRead() async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', SupabaseService.currentUserId ?? '')
          .isFilter('read_at', 'is', null);
      return const Success(null);
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  Future<Result<int>> unreadNotificationCount() async {
    try {
      final data = await _client
          .from('notifications')
          .select('id')
          .eq('recipient_id', SupabaseService.currentUserId ?? '')
          .isFilter('read_at', 'is', null);
      return Success(_rows(data).length);
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  /// Audit trail entries, newest first. Admin-only in the RLS policies.
  Future<Result<List<AuditLog>>> auditLog({int limit = 200}) async {
    try {
      final data = await _client
          .from('audit_logs')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);
      return Result.success(
        _rows(data).map(AuditLog.fromMap).toList(),
      );
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  static AssetTransaction _flatten(Map<String, dynamic> row) {
    final asset = _firstMap(row['assets']);
    final profile = _firstMap(row['profiles']);
    final booking = _firstMap(row['bookings']);
    return AssetTransaction.fromMap({
      ...row,
      'asset_name': asset?['name'],
      'asset_code': asset?['asset_code'],
      'borrower_name': profile?['full_name'],
      'booking_code': booking?['request_id'],
      'expected_return_at': booking?['expected_return_time'],
    });
  }

  /// Normalises a PostgREST payload down to a single row.
  ///
  /// `rpc` returns a **list** when the function returns a table and a bare
  /// value when it returns a scalar, and a joined to-one relation arrives
  /// wrapped in a list. All three shapes collapse here so a caller can simply
  /// ask for "the row".
  static Map<String, dynamic>? _firstMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) {
      return data
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return const [];
  }
}

/// Maintenance faults against assets.
class MaintenanceRepository {
  const MaintenanceRepository();

  SupabaseClient get _client => SupabaseService.client;

  Future<Result<List<MaintenanceRecord>>> all() async {
    try {
      final data = await _client
          .from('maintenance_records')
          .select('*, assets ( name, asset_code )')
          .order('reported_at', ascending: false);
      return Result.success(
        _rows(data).map(_flatten).toList(),
      );
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  Future<Result<MaintenanceRecord>> report({
    required String assetId,
    required String issue,
  }) async {
    try {
      final data = await _client
          .from('maintenance_records')
          .insert({
            'asset_id': assetId,
            'issue_description': issue.trim(),
            'status': MaintenanceStatus.open.wire,
            'reported_by': SupabaseService.currentUserId,
          })
          .select('*, assets ( name, asset_code )')
          .single();
      return Success(_flatten(data));
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  Future<Result<void>> resolve(String id, {String? notes}) async {
    try {
      await _client
          .from('maintenance_records')
          .update({
            'status': MaintenanceStatus.resolved.wire,
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
            'resolution_notes': notes,
          })
          .eq('id', id);
      return const Success(null);
    } catch (error) {
      return Result.failure(SupabaseService.describeError(error));
    }
  }

  static MaintenanceRecord _flatten(Map<String, dynamic> row) {
    final asset = TransactionRepository._firstMap(row['assets']);
    return MaintenanceRecord.fromMap({
      ...row,
      'asset_name': asset?['name'],
      'asset_code': asset?['asset_code'],
    });
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