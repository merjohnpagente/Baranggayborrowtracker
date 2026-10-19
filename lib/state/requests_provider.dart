import 'package:flutter/foundation.dart';

import '../data/models/asset.dart';
import '../data/models/borrow_request.dart';
import '../data/repositories/borrow_repository.dart';

/// Holds everything about borrowing: the signed-in user's requests plus the
/// official queues. One provider keeps the dashboard and the approval screen
/// in sync without extra round trips.
class RequestsProvider extends ChangeNotifier {
  RequestsProvider(this._repository);

  final BorrowRepository _repository;

  List<BorrowRequest> _mine = const [];
  List<BorrowRequest> _pendingReviews = const [];
  List<BorrowRequest> _ongoing = const [];
  bool _loading = false;
  bool _reviewedOverdue = false;

  List<BorrowRequest> get mine => _mine;

  List<BorrowRequest> get pendingReviews => _pendingReviews;

  List<BorrowRequest> get ongoing => _ongoing;

  bool get loading => _loading;

  List<BorrowRequest> get openMine =>
      _mine.where((r) => r.status.isOpen).toList();

  List<BorrowRequest> get activeMine =>
      _mine.where((r) => r.status.isActive).toList();

  List<BorrowRequest> get overdueMine =>
      _mine.where((r) => r.isLate).toList();

  List<BorrowRequest> upcomingMine {
    final active = activeMine;
    active.sort((a, b) => a.returnDate.compareTo(b.returnDate));
    return active;
  }

  List<BorrowRequest> get overdueOngoing =>
      _ongoing.where((r) => r.isLate).toList();

  Future<void> load({bool refreshOverdue = true}) async {
    _loading = true;
    notifyListeners();
    try {
      if (refreshOverdue && !_reviewedOverdue) {
        await _repository.refreshOverdue();
        _reviewedOverdue = true;
      }
      _mine = await _repository.fetchMyRequests();
    } catch (_) {
      _mine = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadOfficialQueues() async {
    _loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.fetchPendingReviews(),
        _repository.fetchOngoingRequests(),
      ]);
      _pendingReviews = results[0];
      _ongoing = results[1];
    } catch (_) {
      _pendingReviews = const [];
      _ongoing = const [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll({bool isOfficial = false}) async {
    await load();
    if (isOfficial) {
      await loadOfficialQueues();
    }
  }

  Future<BorrowRequest?> fetchById(String id) async {
    try {
      return await _repository.fetchById(id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isAssetAvailable({
    required String assetId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      return await _repository.isAssetAvailable(
        assetId: assetId,
        from: from,
        to: to,
      );
    } catch (_) {
      return false;
    }
  }

  Future<BorrowRequest> createRequest({
    required String assetId,
    required String purpose,
    required DateTime borrowDate,
    required DateTime returnDate,
    String? notes,
  }) async {
    final request = await _repository.createRequest(
      assetId: assetId,
      purpose: purpose,
      borrowDate: borrowDate,
      returnDate: returnDate,
      notes: notes,
    );
    _mine = [request, ..._mine];
    notifyListeners();
    return request;
  }

  Future<BorrowRequest> review({
    required String id,
    required String reviewerId,
    required bool approve,
    String? remarks,
  }) async {
    final updated = await _repository.review(
      id: id,
      reviewerId: reviewerId,
      approve: approve,
      remarks: remarks,
    );
    _replace(updated);
    return updated;
  }

  Future<BorrowRequest> release({
    required String id,
    required String officerId,
  }) async {
    final updated = await _repository.release(id: id, officerId: officerId);
    _replace(updated);
    return updated;
  }

  Future<BorrowRequest> markReturned({
    required String id,
    required AssetCondition condition,
    String? remarks,
  }) async {
    final updated = await _repository.markReturned(
      id: id,
      condition: condition,
      remarks: remarks,
    );
    _replace(updated);
    _pendingReviews = _pendingReviews.where((r) => r.id != id).toList();
    _ongoing = _ongoing.where((r) => r.id != id).toList();
    notifyListeners();
    return updated;
  }

  Future<BorrowRequest> cancel(String id) async {
    final updated = await _repository.cancel(id);
    _replace(updated);
    return updated;
  }

  void _replace(BorrowRequest updated) {
    _mine = _mine.map((r) => r.id == updated.id ? updated : r).toList();
    _pendingReviews =
        _pendingReviews.map((r) => r.id == updated.id ? updated : r).toList();
    _ongoing = _ongoing.map((r) => r.id == updated.id ? updated : r).toList();
    notifyListeners();
  }
}