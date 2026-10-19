/// One row of `public.notifications`.
///
/// Notifications are written by Postgres (the `bookings_notify` trigger and
/// trigger-based functions only, hence the deliberate absence of an INSERT
/// policy). The client therefore only ever reads them and stamps `read_at`.
enum NotificationType {
  requestSubmitted('request_submitted', 'Request'),
  requestApproved('request_approved', 'Approved'),
  requestRejected('request_rejected', 'Declined'),
  reservationApproaching('reservation_approaching', 'Upcoming'),
  returnDueSoon('return_due_soon', 'Due soon'),
  overdueReturn('overdue_return', 'Overdue'),
  assetReturned('asset_returned', 'Returned'),
  maintenanceAlert('maintenance_alert', 'Maintenance');

  const NotificationType(this.value, this.label);

  final String value;
  final String label;

  /// Unknown values from a newer schema stay readable instead of crashing.
  static NotificationType fromValue(String? value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return NotificationType.requestSubmitted;
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.type,
    this.message,
    this.relatedRecordId,
    this.relatedType,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? message;
  final NotificationType type;

  /// The booking / asset this notification is about, if any.
  final String? relatedRecordId;
  final String? relatedType;

  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  NotificationItem markedRead() => NotificationItem(
        id: id,
        title: title,
        message: message,
        type: type,
        relatedRecordId: relatedRecordId,
        relatedType: relatedType,
        readAt: readAt ?? DateTime.now(),
        createdAt: createdAt,
      );

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Notification',
      message: map['message'] as String?,
      type: NotificationType.fromValue(map['type'] as String?),
      relatedRecordId: map['related_record_id'] as String?,
      relatedType: map['related_type'] as String?,
      readAt: _date(map['read_at']),
      createdAt: _date(map['created_at']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }
}
