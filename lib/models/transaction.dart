import 'booking.dart';

/// The state of a single handover: released on one day, returned on another.
///
/// This is separate from [Booking] on purpose. A booking is the *request*; a
/// transaction is the *custody*. Rule 8 says a returned asset needs a completed
/// transaction, and it is the transaction that carries the condition evidence.
class AssetTransaction {
  final String id;
  final String bookingId;
  final String assetId;
  final String borrowerId;

  final String? releasedBy;
  final String? releasedByName;
  final DateTime? releasedAt;
  final String? initialCondition;
  final String? initialNotes;
  final List<String> includedItems;
  final List<String> releasePhotoUrls;

  final String? returnedTo;
  final String? returnedToName;
  final DateTime? returnedAt;
  final String? returnCondition;
  final String? damageNotes;
  final String? missingItems;
  final String? returnNotes;
  final List<String> returnPhotoUrls;

  final TransactionReturnStatus returnStatus;
  final bool flaggedForInspection;

  final String? assetName;
  final String? assetCode;
  final String? assetImageUrl;
  final String? borrowerName;
  final String? bookingCode;
  final DateTime? expectedReturnAt;

  const AssetTransaction({
    required this.id,
    required this.bookingId,
    required this.assetId,
    required this.borrowerId,
    this.releasedBy,
    this.releasedByName,
    this.releasedAt,
    this.initialCondition,
    this.initialNotes,
    this.includedItems = const [],
    this.releasePhotoUrls = const [],
    this.returnedTo,
    this.returnedToName,
    this.returnedAt,
    this.returnCondition,
    this.damageNotes,
    this.missingItems,
    this.returnNotes,
    this.returnPhotoUrls = const [],
    this.returnStatus = TransactionReturnStatus.open,
    this.flaggedForInspection = false,
    this.assetName,
    this.assetCode,
    this.assetImageUrl,
    this.borrowerName,
    this.bookingCode,
    this.expectedReturnAt,
  });

  factory AssetTransaction.fromMap(Map<String, dynamic> map) =>
      AssetTransaction(
        id: map['id']?.toString() ?? '',
        bookingId: map['booking_id']?.toString() ?? '',
        assetId: map['asset_id']?.toString() ?? '',
        borrowerId: map['borrower_id']?.toString() ?? '',
        releasedBy: map['released_by']?.toString(),
        releasedByName: map['released_by_name'] as String?,
        releasedAt: _parse(map['released_at']),
        initialCondition: map['initial_condition'] as String?,
        initialNotes: map['initial_notes'] as String?,
        includedItems: _stringList(map['included_items']),
        releasePhotoUrls: _stringList(map['release_photo_urls']),
        returnedTo: map['returned_to']?.toString(),
        returnedToName: map['returned_to_name'] as String?,
        returnedAt: _parse(map['returned_at']),
        returnCondition: map['return_condition'] as String?,
        damageNotes: map['damage_notes'] as String?,
        missingItems: map['missing_items'] as String?,
        returnNotes: map['return_notes'] as String?,
        returnPhotoUrls: _stringList(map['return_photo_urls']),
        returnStatus: TransactionReturnStatus.fromWire(
            map['return_status'] as String?),
        flaggedForInspection: map['flagged_for_inspection'] == true,
        assetName: map['asset_name'] as String?,
        assetCode: map['asset_code'] as String?,
        assetImageUrl: map['asset_image_url'] as String?,
        borrowerName: map['borrower_name'] as String?,
        bookingCode: map['booking_code'] as String?,
        expectedReturnAt: _parse(map['expected_return_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'booking_id': bookingId,
        'asset_id': assetId,
        'borrower_id': borrowerId,
        'released_by': releasedBy,
        'released_at': releasedAt?.toIso8601String(),
        'initial_condition': initialCondition,
        'initial_notes': initialNotes,
        'included_items': includedItems,
        'release_photo_urls': releasePhotoUrls,
        'returned_to': returnedTo,
        'returned_at': returnedAt?.toIso8601String(),
        'return_condition': returnCondition,
        'damage_notes': damageNotes,
        'missing_items': missingItems,
        'return_notes': returnNotes,
        'return_photo_urls': returnPhotoUrls,
        'return_status': returnStatus.wire,
        'flagged_for_inspection': flaggedForInspection,
      };

  AssetTransaction copyWith({
    String? returnedTo,
    String? returnedToName,
    DateTime? returnedAt,
    String? returnCondition,
    String? damageNotes,
    String? missingItems,
    String? returnNotes,
    List<String>? returnPhotoUrls,
    TransactionReturnStatus? returnStatus,
    bool? flaggedForInspection,
  }) =>
      AssetTransaction(
        id: id,
        bookingId: bookingId,
        assetId: assetId,
        borrowerId: borrowerId,
        releasedBy: releasedBy,
        releasedByName: releasedByName,
        releasedAt: releasedAt,
        initialCondition: initialCondition,
        initialNotes: initialNotes,
        includedItems: includedItems,
        releasePhotoUrls: releasePhotoUrls,
        returnedTo: returnedTo ?? this.returnedTo,
        returnedToName: returnedToName ?? this.returnedToName,
        returnedAt: returnedAt ?? this.returnedAt,
        returnCondition: returnCondition ?? this.returnCondition,
        damageNotes: damageNotes ?? this.damageNotes,
        missingItems: missingItems ?? this.missingItems,
        returnNotes: returnNotes ?? this.returnNotes,
        returnPhotoUrls: returnPhotoUrls ?? this.returnPhotoUrls,
        returnStatus: returnStatus ?? this.returnStatus,
        flaggedForInspection:
            flaggedForInspection ?? this.flaggedForInspection,
        assetName: assetName,
        assetCode: assetCode,
        assetImageUrl: assetImageUrl,
        borrowerName: borrowerName,
        bookingCode: bookingCode,
        expectedReturnAt: expectedReturnAt,
      );

  /// Outstanding until a return has actually been recorded.
  bool get isOpen => returnedAt == null;

  bool get isOverdueAt(DateTime now) =>
      isOpen &&
      expectedReturnAt != null &&
      expectedReturnAt!.isBefore(now);

  static List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    final raw = value.toString().replaceAll(RegExp(r'^\[|\]$'), '');
    if (raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => s.trim().replaceAll(RegExp(r'^"|"$'), ''))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static DateTime? _parse(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

/// Whether the custody record has been closed out.
enum TransactionReturnStatus {
  open('open', 'Open'),
  completed('completed', 'Completed'),
  flagged('flagged', 'Flagged for inspection');

  const TransactionReturnStatus(this.wire, this.label);

  final String wire;
  final String label;

  static TransactionReturnStatus fromWire(String? value) =>
      TransactionReturnStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => TransactionReturnStatus.open,
      );
}

/// A row in the immutable audit trail.
class AuditLog {
  final String id;
  final String? actorId;
  final String? actorName;
  final String action;
  final String entityType;
  final String entityId;
  final DateTime timestamp;
  final String? details;

  const AuditLog({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.timestamp,
    this.actorId,
    this.actorName,
    this.details,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
        id: map['id']?.toString() ?? '',
        actorId: map['actor_id']?.toString(),
        actorName: map['actor_name'] as String?,
        action: map['action'] as String? ?? '',
        entityType: map['entity_type'] as String? ?? '',
        entityId: map['entity_id']?.toString() ?? '',
        timestamp:
            DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
                DateTime.now(),
        details: map['details'] as String?,
      );
}

/// A fault reported against an asset and its repair state.
class MaintenanceRecord {
  final String id;
  final String assetId;
  final String issueDescription;
  final MaintenanceStatus status;
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  final String? reportedBy;
  final String? reportedByName;
  final String? resolutionNotes;
  final String? assetName;
  final String? assetCode;

  const MaintenanceRecord({
    required this.id,
    required this.assetId,
    required this.issueDescription,
    required this.status,
    required this.reportedAt,
    this.resolvedAt,
    this.reportedBy,
    this.reportedByName,
    this.resolutionNotes,
    this.assetName,
    this.assetCode,
  });

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) =>
      MaintenanceRecord(
        id: map['id']?.toString() ?? '',
        assetId: map['asset_id']?.toString() ?? '',
        issueDescription: map['issue_description'] as String? ?? '',
        status: MaintenanceStatus.fromWire(map['status'] as String?),
        reportedAt: DateTime.tryParse(map['reported_at']?.toString() ?? '') ??
            DateTime.now(),
        resolvedAt: DateTime.tryParse(map['resolved_at']?.toString() ?? ''),
        reportedBy: map['reported_by']?.toString(),
        reportedByName: map['reported_by_name'] as String?,
        resolutionNotes: map['resolution_notes'] as String?,
        assetName: map['asset_name'] as String?,
        assetCode: map['asset_code'] as String?,
      );

  bool get isOpen => status != MaintenanceStatus.resolved;
}

enum MaintenanceStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In progress'),
  resolved('resolved', 'Resolved');

  const MaintenanceStatus(this.wire, this.label);

  final String wire;
  final String label;

  static MaintenanceStatus fromWire(String? value) =>
      MaintenanceStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => MaintenanceStatus.open,
      );
}