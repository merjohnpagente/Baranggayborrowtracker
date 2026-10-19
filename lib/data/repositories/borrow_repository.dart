import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset.dart';
import '../models/borrow_request.dart';

class BorrowRepository {
  BorrowRepository(this._client);

  final SupabaseClient _client;

  static const String _selectFull =
      '*, asset:assets(*, category:asset_categories(*)), '
      'requester:profiles!borrow_requests_user_id_fkey(*)';

  Future<List<BorrowRequest>> fetchMyRequests({RequestStatus? status}) async {
    var query = _client
        .from('borrow_requests')
        .select(_selectFull)
        .eq('user_id', _client.auth.currentUser!.id);

    if (status != null) {
      query = query.eq('status', status.value);
    }

    final data = await query.order('created_at', ascending: false);
    return _parse(data);
  }

  /// Queue for officials: everything still waiting on a decision.
  Future<List<BorrowRequest>> fetchPendingReviews() async {
    final data = await _client
        .from('borrow_requests')
        .select(_selectFull)
        .eq('status', RequestStatus.pending.value)
        .order('borrow_date', ascending: true);
    return _parse(data);
  }

  /// Everything currently out with a resident - used for monitoring.
  Future<List<BorrowRequest>> fetchOngoingRequests() async {
    final data = await _client
        .from('borrow_requests')
        .select(_selectFull)
        .in('status', [
          RequestStatus.approved.value,
          RequestStatus.released.value,
        ])
        .order('return_date', ascending: true);
    return _parse(data);
  }

  Future<BorrowRequest?> fetchById(String id) async {
    final data = await _client
        .from('borrow_requests')
        .select(_selectFull)
        .eq('id', id)
        .maybeSingle();
    return data == null ? null : BorrowRequest.fromMap(data);
  }

  Future<bool> isAssetAvailable({
    required String assetId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await _client.rpc('check_asset_availability', {
      'p_asset_id': assetId,
      'p_borrow_date': _date(from),
      'p_return_date': _date(to),
    });
    return result == true;
  }

  Future<BorrowRequest> createRequest({
    required String assetId,
    required String purpose,
    required DateTime borrowDate,
    required DateTime returnDate,
    String? notes,
  }) async {
    final response = await _client
        .from('borrow_requests')
        .insert({
          'asset_id': assetId,
          'user_id': _client.auth.currentUser!.id,
          'purpose': purpose.trim(),
          'borrow_date': _date(borrowDate),
          'return_date': _date(returnDate),
          'notes': notes,
        })
        .select(_selectFull)
        .single();
    return BorrowRequest.fromMap(response);
  }

  Future<BorrowRequest> review({
    required String id,
    required String reviewerId,
    required bool approve,
    String? remarks,
  }) async {
    final request = await fetchById(id);
    if (request == null) {
      throw const BorrowException('That request no longer exists.');
    }
    final response = await _client
        .from('borrow_requests')
        .update(request.reviewPayload(
          reviewerId: reviewerId,
          approve: approve,
          remarks: remarks,
        ))
        .eq('id', id)
        .select(_selectFull)
        .single();
    return BorrowRequest.fromMap(response);
  }

  Future<BorrowRequest> release({
    required String id,
    required String officerId,
  }) async {
    final request = await fetchById(id);
    if (request == null) {
      throw const BorrowException('That request no longer exists.');
    }
    final response = await _client
        .from('borrow_requests')
        .update(request.releasePayload(officerId))
        .eq('id', id)
        .select(_selectFull)
        .single();
    return BorrowRequest.fromMap(response);
  }

  Future<BorrowRequest> markReturned({
    required String id,
    required AssetCondition condition,
    String? remarks,
  }) async {
    final request = await fetchById(id);
    if (request == null) {
      throw const BorrowException('That request no longer exists.');
    }
    final response = await _client
        .from('borrow_requests')
        .update(request.returnPayload(condition: condition, remarks: remarks))
        .eq('id', id)
        .select(_selectFull)
        .single();
    return BorrowRequest.fromMap(response);
  }

  Future<BorrowRequest> cancel(String id) async {
    final response = await _client
        .from('borrow_requests')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select(_selectFull)
        .single();
    return BorrowRequest.fromMap(response);
  }

  /// Marks released items past their return date as overdue.
  Future<int> refreshOverdue() async {
    final result = await _client.rpc('refresh_overdue_requests');
    return (result as int?) ?? 0;
  }

  List<BorrowRequest> _parse(dynamic data) =>
      ((data as List?) ?? const [])
          .map((row) => BorrowRequest.fromMap(Map<String, dynamic>.from(row)))
          .toList();

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class BorrowException implements Exception {
  const BorrowException(this.message);

  final String message;

  @override
  String toString() => message;
}