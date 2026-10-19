import '../models/booking.dart';

/// Pure booking rules.
///
/// Everything here is a total function of its arguments: no database, no
/// clock, no widgets. That is deliberate — it makes the reservation rules
/// testable with `flutter test` alone (see `test/booking_rules_test.dart`),
/// and it means the same checks can be applied on the client for a fast
/// message *and* re-applied in Postgres so a bypassed client still cannot
/// double-book an asset.
class BookingRules {
  const BookingRules._();

  /// Rule 2: the end time must be later than the start time.
  static bool isValidRange(DateTime start, DateTime end) => end.isAfter(start);

  /// Do two half-open intervals `[aStart, aEnd)` and `[bStart, bEnd)` share
  /// any time?
  ///
  /// Half-open is the point. A booking that ends at 5:00 PM and another that
  /// starts at 5:00 PM do **not** conflict — the asset is back in time for the
  /// next hand-over. Treating the ranges as closed would make a back-to-back
  /// schedule impossible to book.
  static bool overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    if (!isValidRange(aStart, aEnd) || !isValidRange(bStart, bEnd)) {
      // An inverted range is not a "conflict", it is invalid input; callers
      // check validity separately so they can say *why* it failed.
      return false;
    }
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  /// Rule 3: a new request may not overlap an existing *approved* reservation.
  ///
  /// Rule 4 is encoded in the predicate: only statuses where
  /// [BookingStatus.blocksSchedule] are considered, so a pile of pending
  /// requests never blocks the calendar. Pending requests are competing claims
  /// on the same slot; whichever an approver reaches first wins, and the loser
  /// is rejected by [wouldConflictAtApproval] at that moment.
  static List<Booking> conflictsWith(
    Booking candidate,
    Iterable<Booking> existing, {
    String? ignoreBookingId,
  }) {
    return existing
        .where((b) => b.id != candidate.id && b.id != ignoreBookingId)
        .where((b) => b.assetId == candidate.assetId)
        .where((b) => b.status.blocksSchedule)
        .where((b) => overlaps(
              candidate.startTime,
              candidate.endTime,
              b.startTime,
              b.endTime,
            ))
        .toList();
  }

  static bool hasConflict(
    Booking candidate,
    Iterable<Booking> existing, {
    String? ignoreBookingId,
  }) =>
      conflictsWith(candidate, existing, ignoreBookingId: ignoreBookingId)
          .isNotEmpty;

  /// Rule 5: conflicts are re-checked at approval time, not just at submit.
  ///
  /// Between a request being filed and an approver opening it, another
  /// approver may have taken the slot. This is the check that runs inside the
  /// database transaction so two approvers tapping Approve at the same instant
  /// cannot both succeed.
  static bool wouldConflictAtApproval(
    Booking candidate,
    Iterable<Booking> existing,
  ) =>
      hasConflict(candidate, existing, ignoreBookingId: candidate.id);

  /// Is a request window in the past? A request that starts before now cannot
  /// be filed — the alternative is a request that is born overdue.
  static bool startsInFuture(DateTime start, DateTime now) =>
      start.isAfter(now);

  /// How long is overdue, as a human phrase. Used by the dashboard alert and
  /// the notifications list.
  static String overdueBy(DateTime expectedReturn, DateTime now) {
    final diff = now.difference(expectedReturn);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'}';
    }
    final d = diff.inDays;
    return '$d ${d == 1 ? 'day' : 'days'}';
  }

  /// Due-soon window used for the "return due" reminder. Not a hard rule, just
  /// the threshold the notification query uses.
  static bool isDueSoon(
    DateTime expectedReturn,
    DateTime now, {
    Duration within = const Duration(hours: 24),
  }) {
    if (!expectedReturn.isAfter(now)) return false;
    return expectedReturn.isBefore(now.add(within));
  }

  /// Rule 1: only an active, unarchived, available asset may be reserved.
  ///
  /// [statusCanBeRequested] and [isArchived] are passed separately so this
  /// function never has to reach into the asset model, keeping the dependency
  /// pointing one way.
  static bool isAssetEligible({
    required bool statusCanBeRequested,
    required bool isArchived,
    int quantity = 1,
    int requestedQuantity = 1,
  }) {
    if (isArchived) return false;
    if (!statusCanBeRequested) return false;
    // Rule 10: a quantity-based asset cannot be over-committed.
    if (quantity < 1) return false;
    if (requestedQuantity < 1 || requestedQuantity > quantity) return false;
    return true;
  }

  /// Rule 16 / duplicate-submission guard.
  ///
  /// A double-tapped Submit produces two requests seconds apart with identical
  /// details. Rather than a unique-constraint failure the user would see as an
  /// error, the client checks for a near-identical pending request first. The
  /// database still holds the authoritative unique index — this only spares a
  /// person from filling in the same form twice.
  static bool isDuplicateOf(
    Booking candidate,
    Iterable<Booking> existing, {
    Duration window = const Duration(minutes: 2),
  }) {
    return existing.any((b) {
      if (b.borrowerId != candidate.borrowerId) return false;
      if (b.assetId != candidate.assetId) return false;
      if (!b.status.isOpen) return false;
      if (b.startTime != candidate.startTime) return false;
      if (b.endTime != candidate.endTime) return false;
      return b.submittedAt
          .difference(candidate.submittedAt)
          .abs()
          .inMinutes <=
          window.inMinutes;
    });
  }

  /// Rule 11: a state change is only legal if the status machine allows it.
  /// Mirrors the `booking_status_transition` trigger in the schema.
  static bool canTransition(BookingStatus from, BookingStatus to) =>
      from.canTransitionTo(to);

  /// Which transitions a given actor may perform. This is a *convenience* for
  /// the UI; the same matrix is enforced by RLS and by the RPC functions.
  static bool actorMayTransition({
    required BookingStatus from,
    required BookingStatus to,
    required bool isAdmin,
    required bool isApprover,
    required bool isStaff,
    required bool isOwner,
  }) {
    if (!canTransition(from, to)) return false;
    return switch (to) {
      BookingStatus.approved ||
      BookingStatus.rejected =>
        isAdmin || isApprover,
      BookingStatus.released ||
      BookingStatus.returned =>
        isAdmin || isStaff,
      BookingStatus.cancelled => isAdmin || isStaff || isOwner,
      BookingStatus.overdue || BookingStatus.completed => true,
    };
  }
}