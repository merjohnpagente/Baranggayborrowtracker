import '../local/local_store.dart';
import '../models/dashboard_summary.dart';

/// Computes the aggregate numbers behind the Reports screen.
///
/// These used to be one `dashboard_summary()` SQL function. The queries are
/// small enough that doing them in Dart costs nothing and removes the last
/// reason to keep a server.
class ReportRepository {
  ReportRepository(this._store);

  final LocalStore _store;

  Future<DashboardSummary> fetchSummary() async {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    final assets = _store.assets
        .where((asset) => asset['archived_at'] == null)
        .toList();
    final bookings = _store.bookings;

    final active = assets.where((asset) => asset['status'] == 'available');
    final borrowed = assets.where((asset) => asset['status'] == 'borrowed');

    final pending = bookings
        .where((booking) => booking['status'] == 'pending')
        .length;

    final overdue = bookings.where((booking) {
      final status = booking['status'];
      if (status != 'released' && status != 'overdue') return false;
      final due = DateTime.tryParse('${booking['expected_return_time']}');
      return due != null && due.isBefore(now);
    }).length;

    final upcoming = bookings.where((booking) {
      if (booking['status'] != 'approved') return false;
      final start = DateTime.tryParse('${booking['start_time']}');
      return start != null &&
          start.isAfter(now) &&
          !start.isAfter(weekFromNow);
    }).length;

    final maintenance =
        assets.where((asset) => asset['status'] == 'maintenance').length;

    return DashboardSummary(
      totalAssets: assets.length,
      availableAssets: active.length,
      borrowedAssets: borrowed.length,
      pendingRequests: pending,
      overdueReturns: overdue,
      upcomingReservations: upcoming,
      activeMaintenance: maintenance,
    );
  }
}

class ReportException implements Exception {
  const ReportException(this.message);

  final String message;

  @override
  String toString() => message;
}
