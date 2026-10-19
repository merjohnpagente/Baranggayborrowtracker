/// The row returned by the `dashboard_summary()` Postgres function.
///
/// Every number is computed from real rows inside Postgres, so a report cannot
/// disagree with the dashboard. Bigints arrive as JSON numbers.
class DashboardSummary {
  const DashboardSummary({
    required this.totalAssets,
    required this.availableAssets,
    required this.borrowedAssets,
    required this.pendingRequests,
    required this.overdueReturns,
    required this.upcomingReservations,
    required this.activeMaintenance,
  });

  final int totalAssets;
  final int availableAssets;
  final int borrowedAssets;
  final int pendingRequests;
  final int overdueReturns;
  final int upcomingReservations;
  final int activeMaintenance;

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    return DashboardSummary(
      totalAssets: _int(map['total_assets']),
      availableAssets: _int(map['available_assets']),
      borrowedAssets: _int(map['borrowed_assets']),
      pendingRequests: _int(map['pending_requests']),
      overdueReturns: _int(map['overdue_returns']),
      upcomingReservations: _int(map['upcoming_reservations']),
      activeMaintenance: _int(map['active_maintenance']),
    );
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
