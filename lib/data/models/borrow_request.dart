import 'asset.dart';
import 'user_profile.dart';

/// Lifecycle of a request. Mirrors the `booking_status` enum in `schema.sql`.
///
/// `validate_booking_status_transition` (a BEFORE UPDATE trigger) refuses any
/// move not in [BookingStatus.canTransitionTo], so the machine is enforced by
/// the database even if a client sends a raw update.
enum RequestStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled'),
  released('released', 'Released'),
  returned('returned', 'Returned'),
  overdue('overdue', 'Overdue'),
  completed('completed', 'Completed');

  const RequestStatus(this.value, this.label);

  final String value;
  final String label;

  /// Legal moves, mirroring the trigger.
  Set<RequestStatus> get transitionsTo => switch (this) {
        RequestStatus.pending => {
            RequestStatus.approved,
            RequestStatus.rejected,
            RequestStatus.cancelled,
          },
        RequestStatus.approved => {
            RequestStatus.released,
            RequestStatus.cancelled,
            RequestStatus.overdue,
          },
        RequestStatus.released => {
            RequestStatus.returned,
            RequestStatus.overdue,
          },
        RequestStatus.overdue => {RequestStatus.returned},
        RequestStatus.returned => {RequestStatus.completed},
        RequestStatus.rejected ||
        RequestStatus.cancelled ||
        RequestStatus.completed =>
          const {},
      };

  bool canTransitionTo(RequestStatus next) => transitionsTo.contains(next);

  /// Not finished: still pending, approved, out, or overdue.
  bool get isOpen => const {
        RequestStatus.pending,
        RequestStatus.approved,
        RequestStatus.released,
        RequestStatus.overdue,
      }.contains(this);

  /// The decision has been made and the item is committed to someone.
  bool get isActive =>
      this == RequestStatus.approved ||
      this == RequestStatus.released ||
      this == RequestStatus.overdue;

  /// Awaiting a decision — the only state where Approve / Reject apply.
  bool get isDecidable => this == RequestStatus.pending;

  /// A borrower may withdraw while it has not been handed over.
  bool get isCancellableByOwner =>
      this == RequestStatus.pending || this == RequestStatus.approved;

  /// Only an approved request can be released.
  bool get isReleasable => this == RequestStatus.approved;

  /// Only an item that is out can be returned.
  bool get isReturnable =>
      this == RequestStatus.released || this == RequestStatus.overdue;

  static RequestStatus fromValue(String? value) => values.firstWhere(
        (status) => status.value == value,
        orElse: () => RequestStatus.pending,
      );
}

/// What the booking is for — drives which fields the form shows.
enum BookingType {
  borrow('borrow', 'Borrow'),
  reservation('reservation', 'Reservation'),
  event('event', 'Event');

  const BookingType(this.value, this.label);

  final String value;
  final String label;

  static BookingType fromValue(String? value) => values.firstWhere(
        (t) => t.value == value,
        orElse: () => BookingType.borrow,
      );
}

/// One borrow or reservation request.
///
/// Dart field names differ from the column names on purpose — `borrowDate`
/// reads better than `start_time` in a form, and keeping the translation in
/// one place ([BorrowRequest.fromMap] / [BorrowRequest.toInsert]) means a
/// column rename does not ripple through every screen.
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
    this.bookingType = BookingType.borrow,
    this.notes,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewRemarks,
    this.authorizedDriverId,
    this.authorizedDriverName,
    this.releasedBy,
    this.releasedAt,
    this.returnedAt,
    this.cancelledAt,
    this.returnCondition,
    this.returnRemarks,
    this.documentUrls = const [],
    this.overdue = false,
    this.createdAt,
    this.asset,
    this.requester,
  });

  final String id;

  /// `bookings.request_id` — the human reference on the paper form.
  final String referenceNo;

  final String assetId;

  /// `bookings.borrower_id`. Nullable in the database (ON DELETE SET NULL).
  final String userId;

  final String purpose;

  /// `start_time`.
  final DateTime borrowDate;

  /// `expected_return_time` — when the item is due back.
  final DateTime returnDate;

  final RequestStatus status;
  final BookingType bookingType;
  final String? notes;

  /// `approved_by` / `approved_at`.
  final String? reviewedBy;
  final DateTime? reviewedAt;

  /// `rejection_reason`.
  final String? reviewRemarks;

  final String? authorizedDriverId;
  final String? authorizedDriverName;

  final String? releasedBy;
  final DateTime? releasedAt;
  final DateTime? returnedAt;
  final DateTime? cancelledAt;

  final AssetCondition? returnCondition;
  final String? returnRemarks;

  /// `bookings.document_urls` (text[]).
  final List<String> documentUrls;

  /// Denormalised by the queries for list views; `overdue` is also computed
  /// server-side by `mark_overdue_bookings`.
  final bool overdue;

  /// `submitted_at`.
  final DateTime? createdAt;

  /// Embedded for display when the query joined it.
  final Asset? asset;
  final UserProfile? requester;

  /// `end_time` — when the reservation window closes.
  DateTime get endsAt => returnDate;

  /// Late if the item is still out past its due time.
  ///
  /// A returned item is never late, however old the dates are — otherwise
  /// every completed loan would sit on the overdue list forever.
  bool get isLate =>
      overdue ||
      (const {RequestStatus.released, RequestStatus.overdue}.contains(status) &&
          DateTime.now().isAfter(returnDate));

  /// Days the item is out, counting both ends.
  int get totalDays {
    final start = DateTime(borrowDate.year, borrowDate.month, borrowDate.day);
    final end = DateTime(returnDate.year, returnDate.month, returnDate.day);
    return end.difference(start).inDays + 1;
  }

  factory BorrowRequest.fromMap(Map<String, dynamic> map) {
    // The return condition and damage notes live on `transactions`, not on the
    // booking. The queries embed that row as `transaction` (booking_id is
    // unique, so it is at most one), and this reads them from there when the
    // embedding was requested. A plain row without the embed still parses.
    final transaction = map['transaction'] is Map
        ? Map<String, dynamic>.from(map['transaction'] as Map)
        : const <String, dynamic>{};

    final rawCondition =
        map['return_condition'] ?? transaction['return_condition'];

    return BorrowRequest(
      id: map['id'] as String? ?? '',
      referenceNo: (map['request_id'] as String?) ?? '—',
      assetId: (map['asset_id'] as String?) ?? '',
      userId: (map['borrower_id'] as String?) ?? '',
      purpose: (map['purpose'] as String?) ?? '',
      bookingType: BookingType.fromValue(map['booking_type'] as String?),
      borrowDate: _date(map['start_time']),
      returnDate: _date(map['expected_return_time'], fallback: map['end_time']),
      notes: map['notes'] as String?,
      reviewedBy: map['approved_by'] as String?,
      reviewedAt: _dateOrNull(map['approved_at']),
      reviewRemarks: map['rejection_reason'] as String?,
      authorizedDriverId: map['authorized_driver_id'] as String?,
      authorizedDriverName: map['authorized_driver_name'] as String?,
      releasedBy:
          (map['released_by'] as String?) ?? transaction['released_by'] as String?,
      releasedAt: _dateOrNull(map['released_at']),
      returnedAt: _dateOrNull(map['returned_at']),
      cancelledAt: _dateOrNull(map['cancelled_at']),
      returnCondition: rawCondition == null
          ? null
          : AssetCondition.fromValue(rawCondition as String?),
      returnRemarks:
          (map['return_remarks'] as String?) ?? transaction['damage_notes'] as String?,
      documentUrls: _stringList(map['document_urls']),
      status: RequestStatus.fromValue(map['status'] as String?),
      overdue: (map['overdue'] as bool?) ?? false,
      createdAt: _dateOrNull(map['submitted_at']),
      // Embedded relations arrive under different keys depending on the alias
      // used in the select; accept either.
      asset: map['asset'] is Map
          ? Asset.fromMap(Map<String, dynamic>.from(map['asset'] as Map))
          : null,
      requester: map['requester'] is Map
          ? UserProfile.fromMap(Map<String, dynamic>.from(map['requester'] as Map))
          : null,
    );
  }

  /// Columns for INSERT.
  ///
  /// `status` is deliberately **not** sent: the column defaults to `pending`
  /// and the RLS insert policy requires it, so a modified client cannot file
  /// a self-approved request.
  Map<String, dynamic> toInsert() => {
        'asset_id': assetId,
        'borrower_id': userId,
        'booking_type': bookingType.value,
        'purpose': purpose,
        'start_time': borrowDate.toUtc().toIso8601String(),
        'end_time': returnDate.toUtc().toIso8601String(),
        'expected_return_time': returnDate.toUtc().toIso8601String(),
        'authorized_driver_id': authorizedDriverId,
        'authorized_driver_name': authorizedDriverName,
        'notes': notes,
        'document_urls': documentUrls,
      };

  Map<String, dynamic> toUpdate() => toInsert();

  static DateTime _date(Object? value, {Object? fallback}) =>
      DateTime.tryParse((value ?? fallback ?? '').toString()) ?? DateTime.now();

  static DateTime? _dateOrNull(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  static List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}