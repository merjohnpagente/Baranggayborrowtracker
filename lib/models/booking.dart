import 'package:flutter/material.dart';

/// Lifecycle of a borrow / reservation request.
///
/// The legal moves are declared in [BookingStatus.transitionsTo] and are the
/// single source of truth in the app; the same rules are re-declared as a
/// Postgres trigger in `supabase/schema.sql`, because a client check is a
/// courtesy, not a control.
///
///   pending ──approve──▶ approved ──release──▶ released ──return──▶ returned
///      │                    │                     │
///      ├──reject──▶ rejected                      ├──(past due)──▶ overdue──▶ returned
///      └──cancel──▶ cancelled
///
/// [returned] and [overdue] are both terminal-until-returned; [overdue] is
/// derived from the return clock, not something a user can set by hand.
enum BookingStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled'),
  released('released', 'Released'),
  returned('returned', 'Returned'),
  overdue('overdue', 'Overdue'),
  completed('completed', 'Completed');

  const BookingStatus(this.wire, this.label);

  final String wire;
  final String label;

  static BookingStatus fromWire(String? value) =>
      BookingStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => BookingStatus.pending,
      );

  /// Statuses this one may legally move to.
  ///
  /// Guards the UI and is mirrored by the database so a stale or tampered
  /// client cannot, for example, approve an already-rejected request.
  Set<BookingStatus> get transitionsTo => switch (this) {
        BookingStatus.pending => {
            BookingStatus.approved,
            BookingStatus.rejected,
            BookingStatus.cancelled,
          },
        BookingStatus.approved => {
            BookingStatus.released,
            BookingStatus.cancelled,
            BookingStatus.overdue,
          },
        BookingStatus.released => {BookingStatus.returned, BookingStatus.overdue},
        // Returned and cancelled are terminal; completed is reached from
        // returned when the paperwork closes out.
        BookingStatus.overdue => {BookingStatus.returned},
        BookingStatus.returned => {BookingStatus.completed},
        BookingStatus.rejected => const {},
        BookingStatus.cancelled => const {},
        BookingStatus.completed => const {},
      };

  bool canTransitionTo(BookingStatus next) => transitionsTo.contains(next);

  /// The request is still live and has not yet been handed over.
  bool get isOpen => const {
        BookingStatus.pending,
        BookingStatus.approved,
        BookingStatus.released,
        BookingStatus.overdue,
      }.contains(this);

  /// The asset is physically out with the borrower.
  bool get isOut =>
      this == BookingStatus.released || this == BookingStatus.overdue;

  /// Approve / reject buttons are only meaningful from [pending].
  bool get isAwaitingDecision => this == BookingStatus.pending;

  /// A resident may withdraw their own request while it has not been actioned.
  bool get isCancellableByOwner =>
      this == BookingStatus.pending || this == BookingStatus.approved;

  /// Staff can release an asset once a request is approved.
  bool get isReleasable => this == BookingStatus.approved;

  /// Staff can receive it back once it is out.
  bool get isReturnable =>
      this == BookingStatus.released || this == BookingStatus.overdue;
}

/// Colours live here rather than in the theme so a badge can be built from a
/// status without importing the theme, and so the light/dark pair for a given
/// status is defined in one place.
extension BookingStatusColors on BookingStatus {
  Color get color => switch (this) {
        BookingStatus.pending => const Color(0xFFB45309),
        BookingStatus.approved => const Color(0xFF169B62),
        BookingStatus.rejected => const Color(0xFFDC3545),
        BookingStatus.cancelled => const Color(0xFF64748B),
        BookingStatus.released => const Color(0xFF1769AA),
        BookingStatus.returned => const Color(0xFF169B62),
        BookingStatus.overdue => const Color(0xFFDC3545),
        BookingStatus.completed => const Color(0xFF64748B),
      };

  Color get background => switch (this) {
        BookingStatus.pending => const Color(0xFFFEF3E2),
        BookingStatus.approved => const Color(0xFFE4F6EE),
        BookingStatus.rejected => const Color(0xFFFDEBEC),
        BookingStatus.cancelled => const Color(0xFFEFF3F9),
        BookingStatus.released => const Color(0xFFE4F0FA),
        BookingStatus.returned => const Color(0xFFE4F6EE),
        BookingStatus.overdue => const Color(0xFFFDEBEC),
        BookingStatus.completed => const Color(0xFFEFF3F9),
      };

  IconData get icon => switch (this) {
        BookingStatus.pending => Icons.hourglass_top,
        BookingStatus.approved => Icons.check_circle_outline,
        BookingStatus.rejected => Icons.cancel_outlined,
        BookingStatus.cancelled => Icons.remove_circle_outline,
        BookingStatus.released => Icons.outbound,
        BookingStatus.returned => Icons.assignment_turned_in_outlined,
        BookingStatus.overdue => Icons.running_with_errors,
        BookingStatus.completed => Icons.done_all,
      };
}

/// One borrow or reservation request.
class Booking {
  final String id;
  final String requestId;
  final String assetId;
  final String assetName;
  final String assetCode;

  final String borrowerId;
  final String borrowerName;
  final String? borrowerPhone;
  final String? contactEmail;

  final String purpose;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime expectedReturnTime;

  final String? authorizedDriverId;
  final String? authorizedDriverName;

  final BookingStatus status;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? notes;
  final List<String> documentUrls;
  final DateTime submittedAt;
  final DateTime? cancelledAt;
  final DateTime? releasedAt;
  final DateTime? returnedAt;

  const Booking({
    required this.id,
    required this.requestId,
    required this.assetId,
    this.assetName = '',
    this.assetCode = '',
    required this.borrowerId,
    this.borrowerName = '',
    this.borrowerPhone,
    this.contactEmail,
    required this.purpose,
    required this.startTime,
    required this.endTime,
    required this.expectedReturnTime,
    this.authorizedDriverId,
    this.authorizedDriverName,
    this.status = BookingStatus.pending,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    this.notes,
    this.documentUrls = const [],
    required this.submittedAt,
    this.cancelledAt,
    this.releasedAt,
    this.returnedAt,
  });

  factory Booking.fromMap(Map<String, dynamic> map) => Booking(
        id: map['id']?.toString() ?? '',
        requestId: map['request_id'] as String? ?? '',
        assetId: map['asset_id']?.toString() ?? '',
        assetName: (map['asset_name'] as String?) ?? '',
        assetCode: (map['asset_code'] as String?) ?? '',
        borrowerId: map['borrower_id']?.toString() ?? '',
        borrowerName: (map['borrower_name'] as String?) ?? '',
        borrowerPhone: map['borrower_phone'] as String?,
        contactEmail: map['contact_email'] as String?,
        purpose: map['purpose'] as String? ?? '',
        startTime: _parse(map['start_time']) ?? DateTime.now(),
        endTime: _parse(map['end_time']) ?? DateTime.now(),
        expectedReturnTime:
            _parse(map['expected_return_time']) ?? DateTime.now(),
        authorizedDriverId: map['authorized_driver_id']?.toString(),
        authorizedDriverName: map['authorized_driver_name'] as String?,
        status: BookingStatus.fromWire(map['status'] as String?),
        approvedBy: map['approved_by']?.toString(),
        approvedByName: map['approved_by_name'] as String?,
        approvedAt: _parse(map['approved_at']),
        rejectionReason: map['rejection_reason'] as String?,
        notes: map['notes'] as String?,
        documentUrls: _stringList(map['document_urls']),
        submittedAt: _parse(map['submitted_at']) ?? DateTime.now(),
        cancelledAt: _parse(map['cancelled_at']),
        releasedAt: _parse(map['released_at']),
        returnedAt: _parse(map['returned_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'request_id': requestId,
        'asset_id': assetId,
        'asset_name': assetName,
        'asset_code': assetCode,
        'borrower_id': borrowerId,
        'borrower_name': borrowerName,
        'borrower_phone': borrowerPhone,
        'contact_email': contactEmail,
        'purpose': purpose,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'expected_return_time': expectedReturnTime.toIso8601String(),
        'authorized_driver_id': authorizedDriverId,
        'authorized_driver_name': authorizedDriverName,
        'status': status.wire,
        'approved_by': approvedBy,
        'approved_by_name': approvedByName,
        'approved_at': approvedAt?.toIso8601String(),
        'rejection_reason': rejectionReason,
        'notes': notes,
        'document_urls': documentUrls,
        'submitted_at': submittedAt.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'released_at': releasedAt?.toIso8601String(),
        'returned_at': returnedAt?.toIso8601String(),
      };

  Booking copyWith({
    BookingStatus? status,
    String? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
    String? rejectionReason,
    DateTime? cancelledAt,
    DateTime? releasedAt,
    DateTime? returnedAt,
  }) =>
      Booking(
        id: id,
        requestId: requestId,
        assetId: assetId,
        assetName: assetName,
        assetCode: assetCode,
        borrowerId: borrowerId,
        borrowerName: borrowerName,
        borrowerPhone: borrowerPhone,
        contactEmail: contactEmail,
        purpose: purpose,
        startTime: startTime,
        endTime: endTime,
        expectedReturnTime: expectedReturnTime,
        authorizedDriverId: authorizedDriverId,
        authorizedDriverName: authorizedDriverName,
        status: status ?? this.status,
        approvedBy: approvedBy ?? this.approvedBy,
        approvedByName: approvedByName ?? this.approvedByName,
        approvedAt: approvedAt ?? this.approvedAt,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        notes: notes,
        documentUrls: documentUrls,
        submittedAt: submittedAt,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        releasedAt: releasedAt ?? this.releasedAt,
        returnedAt: returnedAt ?? this.returnedAt,
      );

  bool get isOverdue {
    if (returnedAt != null) return false;
    return DateTime.now().isAfter(expectedReturnTime);
  }

  /// Hours until the return is due. Negative when overdue.
  Duration get timeUntilDue => expectedReturnTime.difference(DateTime.now());

  static DateTime? _parse(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}