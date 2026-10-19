import '../../core/utils/formatters.dart';
import 'asset.dart';
import 'user_profile.dart';

enum RequestStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  declined('declined', 'Declined'),
  released('released', 'Released'),
  returned('returned', 'Returned'),
  cancelled('cancelled', 'Cancelled');

  const RequestStatus(this.value, this.label);

  final String value;
  final String label;

  bool get isOpen =>
      this == RequestStatus.pending ||
      this == RequestStatus.approved ||
      this == RequestStatus.released;

  bool get isActive =>
      this == RequestStatus.approved || this == RequestStatus.released;

  static RequestStatus fromValue(String? value) => values.firstWhere(
        (status) => status.value == value,
        orElse: () => RequestStatus.pending,
      );
}

class BorrowRequest {
  const BorrowRequest({
    required this.id,
    required this.referenceNo,
    required this.assetId,
    required this.userId,
    required this.purpose,
    required this.borrowDate,
    required this.returnDate,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewRemarks,
    this.releasedBy,
    this.releasedAt,
    this.returnedAt,
    this.returnCondition,
    this.returnRemarks,
    this.overdue = false,
    this.createdAt,
    this.asset,
    this.requester,
  });

  final String id;
  final String referenceNo;
  final String assetId;
  final String userId;
  final String purpose;
  final DateTime borrowDate;
  final DateTime returnDate;
  final RequestStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewRemarks;
  final String? releasedBy;
  final DateTime? releasedAt;
  final DateTime? returnedAt;
  final AssetCondition? returnCondition;
  final String? returnRemarks;
  final bool overdue;
  final DateTime? createdAt;
  final Asset? asset;
  final UserProfile? requester;

  /// The person who will physically hand over / receive the item.
  UserProfile? get official => requester;

  bool get isLate =>
      overdue ||
      (status == RequestStatus.released &&
          DateTime.now().isAfter(DateTime(
            returnDate.year,
            returnDate.month,
            returnDate.day,
            23,
            59,
          )));

  int get totalDays => Fmt.inclusiveDays(borrowDate, returnDate);

  factory BorrowRequest.fromMap(Map<String, dynamic> map) {
    final assetMap = map['asset'];
    final requesterMap = map['requester'];
    return BorrowRequest(
      id: map['id'] as String,
      referenceNo: (map['reference_no'] as String?) ?? '—',
      assetId: (map['asset_id'] as String?) ?? '',
      userId: (map['user_id'] as String?) ?? '',
      purpose: (map['purpose'] as String?) ?? '',
      borrowDate:
          DateTime.tryParse((map['borrow_date'] ?? '').toString()) ?? DateTime.now(),
      returnDate:
          DateTime.tryParse((map['return_date'] ?? '').toString()) ?? DateTime.now(),
      status: RequestStatus.fromValue(map['status'] as String?),
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: map['reviewed_at'] == null
          ? null
          : DateTime.tryParse(map['reviewed_at'] as String),
      reviewRemarks: map['review_remarks'] as String?,
      releasedBy: map['released_by'] as String?,
      releasedAt: map['released_at'] == null
          ? null
          : DateTime.tryParse(map['released_at'] as String),
      returnedAt: map['returned_at'] == null
          ? null
          : DateTime.tryParse(map['returned_at'] as String),
      returnCondition: map['return_condition'] == null
          ? null
          : AssetCondition.fromValue(map['return_condition'] as String?),
      returnRemarks: map['return_remarks'] as String?,
      overdue: (map['overdue'] as bool?) ?? false,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
      asset: assetMap is Map
          ? Asset.fromMap(Map<String, dynamic>.from(assetMap))
          : null,
      requester: requesterMap is Map
          ? UserProfile.fromMap(Map<String, dynamic>.from(requesterMap))
          : null,
    );
  }

  /// Fields an official fills in when reviewing or releasing.
  Map<String, dynamic> reviewPayload({
    required String reviewerId,
    required bool approve,
    String? remarks,
  }) =>
      {
        'status': approve ? 'approved' : 'declined',
        'reviewed_by': reviewerId,
        'reviewed_at': DateTime.now().toIso8601String(),
        'review_remarks': remarks,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Map<String, dynamic> releasePayload(String officerId) => {
        'status': 'released',
        'released_by': officerId,
        'released_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  Map<String, dynamic> returnPayload({
    required AssetCondition condition,
    String? remarks,
  }) =>
      {
        'status': 'returned',
        'returned_at': DateTime.now().toIso8601String(),
        'return_condition': condition.value,
        'return_remarks': remarks,
        'overdue': isLate,
        'updated_at': DateTime.now().toIso8601String(),
      };
}