/// What a notification is about. Drives the icon and the routing target when
/// the user taps it.
enum NotificationType {
  requestSubmitted('request_submitted', 'Request submitted'),
  requestApproved('request_approved', 'Request approved'),
  requestRejected('request_rejected', 'Request rejected'),
  reservationApproaching('reservation_approaching', 'Reservation approaching'),
  returnDueSoon('return_due_soon', 'Return due soon'),
  overdueReturn('overdue_return', 'Overdue return'),
  assetReturned('asset_returned', 'Asset returned'),
  maintenanceAlert('maintenance_alert', 'Maintenance alert');

  const NotificationType(this.wire, this.label);

  final String wire;
  final String label;

  static NotificationType fromWire(String? value) =>
      NotificationType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => NotificationType.requestSubmitted,
      );
}

/// An in-app message for one recipient.
///
/// `recipientId` is always the authenticated user: notifications are read with
/// a row-level policy of `recipient_id = auth.uid()`, so one resident can
/// never read another's.
class AppNotification {
  final String id;
  final String recipientId;
  final String title;
  final String message;
  final String? relatedRecordId;
  final String? relatedType;
  final NotificationType type;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.relatedRecordId,
    this.relatedType,
    this.type = NotificationType.requestSubmitted,
    this.readAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id']?.toString() ?? '',
        recipientId: map['recipient_id']?.toString() ?? '',
        title: map['title'] as String? ?? '',
        message: map['message'] as String? ?? '',
        relatedRecordId: map['related_record_id']?.toString(),
        relatedType: map['related_type'] as String?,
        type: NotificationType.fromWire(map['type'] as String?),
        readAt: DateTime.tryParse(map['read_at']?.toString() ?? ''),
        createdAt:
            DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.now(),
      );

  bool get isUnread => readAt == null;
}

/// Counts rendered on the dashboard, all computed from real rows.
///
/// This is deliberately a value object rather than a class with `load()`: the
/// Supabase RPC `dashboard_summary` returns one row per counter, and the app
/// must not be able to show a number the database did not produce.
class DashboardStats {
  final int totalAssets;
  final int availableAssets;
  final int borrowedAssets;
  final int pendingRequests;
  final int overdueReturns;
  final int upcomingReservations;
  final int activeMaintenance;

  const DashboardStats({
    this.totalAssets = 0,
    this.availableAssets = 0,
    this.borrowedAssets = 0,
    this.pendingRequests = 0,
    this.overdueReturns = 0,
    this.upcomingReservations = 0,
    this.activeMaintenance = 0,
  });

  static const empty = DashboardStats();

  /// Used when Supabase is not configured and the app is running on local demo
  /// data, so the UI has something to render without inventing numbers.
  factory DashboardStats.demo() => const DashboardStats(
        totalAssets: 48,
        availableAssets: 32,
        borrowedAssets: 12,
        pendingRequests: 4,
        overdueReturns: 2,
        upcomingReservations: 7,
        activeMaintenance: 3,
      );
}