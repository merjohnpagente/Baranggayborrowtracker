import 'package:flutter_test/flutter_test.dart';

import 'package:barangay_borrow_tracker/data/models/asset.dart';
import 'package:barangay_borrow_tracker/data/models/asset_category.dart';
import 'package:barangay_borrow_tracker/data/models/borrow_request.dart';
import 'package:barangay_borrow_tracker/data/models/dashboard_summary.dart';
import 'package:barangay_borrow_tracker/data/models/notification_item.dart';
import 'package:barangay_borrow_tracker/data/models/user_profile.dart';

void main() {
  group('AssetStatus', () {
    test('only an available asset can be newly requested', () {
      expect(AssetStatus.available.canRequest, isTrue);
      // A reserved asset already has an approved booking on it; it is not up
      // for grabs even though nothing has been handed over yet.
      expect(AssetStatus.reserved.canRequest, isFalse);
      expect(AssetStatus.borrowed.canRequest, isFalse);
      expect(AssetStatus.maintenance.canRequest, isFalse);
      expect(AssetStatus.retired.canRequest, isFalse);
    });

    test('an unknown value degrades to available rather than throwing', () {
      // A row written by a newer schema must not crash an older client, and
      // must not silently read as "retired" (which would hide the asset).
      expect(AssetStatus.fromValue('something_new'), AssetStatus.available);
      expect(AssetStatus.fromValue(null), AssetStatus.available);
    });
  });

  group('AssetCondition', () {
    test('unknown condition degrades to good', () {
      expect(AssetCondition.fromValue('melted'), AssetCondition.good);
    });

    test('damage and missing items need an inspection', () {
      expect(AssetCondition.good.needsInspection, isFalse);
      expect(AssetCondition.serviceable.needsInspection, isFalse);
      expect(AssetCondition.minorDamage.needsInspection, isTrue);
      expect(AssetCondition.majorDamage.needsInspection, isTrue);
      expect(AssetCondition.missingItems.needsInspection, isTrue);
    });
  });

  group('AssetCategory', () {
    test('every wire value in schema.sql is represented', () {
      expect(
        AssetCategory.values.map((c) => c.value).toSet(),
        {
          'vehicle',
          'facility',
          'equipment',
          'furniture',
          'shelter',
          'electronics',
          'power',
          'other',
        },
      );
    });

    test('an unknown category stays visible as other', () {
      expect(AssetCategory.fromValue('spaceship'), AssetCategory.other);
    });
  });

  group('Asset.fromMap', () {
    test('reads a full row using the real column names', () {
      final asset = Asset.fromMap({
        'id': 'a1',
        'asset_code': 'VEH-001',
        'name': 'Service Vehicle',
        'category': 'vehicle',
        'status': 'borrowed',
        'condition': 'minor_damage',
        'location': 'Barangay Hall',
        'quantity': 1,
        'plate_number': 'ABC 1234',
        'image_urls': ['https://example.test/van.jpg'],
      });
      expect(asset.code, 'VEH-001');
      expect(asset.category, AssetCategory.vehicle);
      expect(asset.status, AssetStatus.borrowed);
      expect(asset.condition, AssetCondition.minorDamage);
      expect(asset.canRequest, isFalse);
      expect(asset.plateNumber, 'ABC 1234');
      expect(asset.imageUrl, 'https://example.test/van.jpg');
    });

    test('missing optional fields fall back without throwing', () {
      final asset = Asset.fromMap({'id': 'a2'});
      expect(asset.code, '');
      expect(asset.name, 'Unnamed asset');
      expect(asset.status, AssetStatus.available);
      expect(asset.category, AssetCategory.other);
      expect(asset.quantity, 1);
      expect(asset.location, isNull);
      expect(asset.imageUrls, isEmpty);
    });

    test('quantity tolerates a numeric string from Postgres', () {
      final asset = Asset.fromMap({'id': 'a3', 'quantity': '12'});
      expect(asset.quantity, 12);
    });

    test('a text[] that arrives as a bracketed string still parses', () {
      final asset = Asset.fromMap({
        'id': 'a4',
        'image_urls': '["https://example.test/a.jpg", "https://example.test/b.jpg"]',
      });
      expect(asset.imageUrls, hasLength(2));
      expect(asset.imageUrl, 'https://example.test/a.jpg');
    });

    test('the QR value falls back to the asset code', () {
      final asset = Asset.fromMap({'id': 'a5', 'asset_code': 'EQP-001'});
      expect(asset.qrCodeValue, 'EQP-001');
    });

    test('archiving removes it from circulation without deleting it', () {
      final asset = Asset.fromMap({
        'id': 'a6',
        'status': 'available',
        'archived_at': '2026-01-01T00:00:00Z',
      });
      expect(asset.isArchived, isTrue);
      expect(asset.canRequest, isFalse);
    });
  });

  group('RequestStatus', () {
    test('only a pending request is decidable', () {
      expect(RequestStatus.pending.isDecidable, isTrue);
      expect(RequestStatus.approved.isDecidable, isFalse);
      expect(RequestStatus.rejected.isDecidable, isFalse);
    });

    test('a borrower may withdraw before handover, not after', () {
      expect(RequestStatus.pending.isCancellableByOwner, isTrue);
      expect(RequestStatus.approved.isCancellableByOwner, isTrue);
      expect(RequestStatus.released.isCancellableByOwner, isFalse);
    });

    test('release and return gates match the database trigger', () {
      expect(RequestStatus.approved.isReleasable, isTrue);
      expect(RequestStatus.pending.isReleasable, isFalse);
      expect(RequestStatus.released.isReturnable, isTrue);
      expect(RequestStatus.overdue.isReturnable, isTrue);
      expect(RequestStatus.approved.isReturnable, isFalse);
    });

    test('transitions mirror schema.sql', () {
      expect(
        RequestStatus.pending.transitionsTo,
        {
          RequestStatus.approved,
          RequestStatus.rejected,
          RequestStatus.cancelled,
        },
      );
      expect(
        RequestStatus.approved.transitionsTo,
        {
          RequestStatus.released,
          RequestStatus.cancelled,
          RequestStatus.overdue,
        },
      );
      expect(
        RequestStatus.returned.transitionsTo,
        {RequestStatus.completed},
      );
      expect(RequestStatus.rejected.transitionsTo, isEmpty);
      expect(RequestStatus.completed.transitionsTo, isEmpty);
    });

    test('unknown status degrades to pending', () {
      expect(RequestStatus.fromValue('brand_new_state'), RequestStatus.pending);
      expect(RequestStatus.fromValue(null), RequestStatus.pending);
    });
  });

  group('BorrowRequest.fromMap', () {
    Map<String, dynamic> row({
      String status = 'pending',
      String start = '2026-05-01T00:00:00Z',
      String due = '2026-05-03T23:59:59Z',
    }) =>
        {
          'id': 'r1',
          'request_id': 'BR-260501-0001',
          'asset_id': 'a1',
          'borrower_id': 'u1',
          'booking_type': 'borrow',
          'purpose': 'Barangay outreach',
          'status': status,
          'start_time': start,
          'end_time': due,
          'expected_return_time': due,
          'submitted_at': '2026-04-28T08:00:00Z',
        };

    test('reads the real column names', () {
      final request = BorrowRequest.fromMap(row());
      expect(request.referenceNo, 'BR-260501-0001');
      expect(request.userId, 'u1');
      expect(request.bookingType, BookingType.borrow);
      expect(request.status, RequestStatus.pending);
      expect(request.createdAt, DateTime.parse('2026-04-28T08:00:00Z'));
    });

    test('computes the loan length inclusively', () {
      final request = BorrowRequest.fromMap(row());
      // Borrowed on the 1st, due at the end of the 3rd: three days.
      expect(request.totalDays, 3);
    });

    test('a returned request is not late however old the dates are', () {
      final request = BorrowRequest.fromMap(
        row(status: 'returned', start: '2020-01-01', due: '2020-01-02'),
      );
      expect(request.isLate, isFalse);
    });

    test('the overdue flag is honoured even before the clock catches up', () {
      final map = row(status: 'released')..['overdue'] = true;
      expect(BorrowRequest.fromMap(map).isLate, isTrue);
    });

    test('a released request past its due time is late', () {
      final request = BorrowRequest.fromMap(
        row(status: 'released', start: '2020-01-01', due: '2020-01-02'),
      );
      expect(request.isLate, isTrue);
    });

    test('a pending request is never late', () {
      final request = BorrowRequest.fromMap(
        row(start: '2020-01-01', due: '2020-01-02'),
      );
      expect(request.isLate, isFalse);
    });

    test('the rejection reason is surfaced as the review note', () {
      final map = row(status: 'rejected')
        ..['rejection_reason'] = 'The court is already booked.';
      final request = BorrowRequest.fromMap(map);
      expect(request.reviewRemarks, 'The court is already booked.');
    });

    test('return details are read from the embedded transaction', () {
      final map = row(status: 'completed')
        ..['transaction'] = {
          'return_condition': 'minor_damage',
          'damage_notes': 'One leg is bent.',
          'released_by': 'u9',
        };
      final request = BorrowRequest.fromMap(map);
      expect(request.returnCondition, AssetCondition.minorDamage);
      expect(request.returnRemarks, 'One leg is bent.');
      expect(request.releasedBy, 'u9');
    });

    test('missing timestamps do not throw', () {
      final request = BorrowRequest.fromMap({
        'id': 'r2',
        'asset_id': 'a1',
        'borrower_id': 'u1',
        'purpose': 'No dates',
      });
      expect(request.status, RequestStatus.pending);
      expect(request.referenceNo, '—');
      expect(request.createdAt, isNull);
    });

    test('toInsert never sends a status', () {
      final request = BorrowRequest.fromMap(row());
      expect(request.toInsert().containsKey('status'), isFalse);
      expect(request.toInsert()['borrower_id'], 'u1');
    });
  });

  group('UserProfile', () {
    test('reads the profile columns and derives initials', () {
      final profile = UserProfile.fromMap({
        'id': 'u1',
        'full_name': 'Juan Dela Cruz',
        'email': 'juan@example.test',
        'phone_number': '09171234567',
        'role': 'resident',
        'account_status': 'active',
        'purok': 'Purok 3',
      });
      expect(profile.initials, 'JD');
      expect(profile.phone, '09171234567');
      expect(profile.purok, 'Purok 3');
      expect(profile.role, UserRole.resident);
      expect(profile.accountStatus, AccountStatus.active);
    });

    test('an unknown or missing role is never privileged', () {
      expect(UserRole.fromValue('superuser'), UserRole.resident);
      expect(UserRole.fromValue(null), UserRole.resident);
      expect(UserRole.resident.isOfficer, isFalse);
      expect(UserRole.approver.canApprove, isTrue);
      expect(UserRole.staff.canHandleAssets, isTrue);
      expect(UserRole.staff.canManageUsers, isFalse);
    });
  });

  group('NotificationItem', () {
    test('an unread row reads as unread and keeps its deep link', () {
      final item = NotificationItem.fromMap({
        'id': 'n1',
        'title': 'Approved — BR-1',
        'message': 'Your request was approved.',
        'type': 'request_approved',
        'related_record_id': 'r1',
        'related_type': 'booking',
        'read_at': null,
        'created_at': '2026-05-01T08:00:00Z',
      });
      expect(item.isUnread, isTrue);
      expect(item.type, NotificationType.requestApproved);
      expect(item.relatedRecordId, 'r1');
      expect(item.createdAt, DateTime.parse('2026-05-01T08:00:00Z').toLocal());
    });

    test('marking read produces a new read copy', () {
      final item = NotificationItem.fromMap({
        'id': 'n2',
        'title': 'Hello',
        'type': 'overdue_return',
      });
      final read = item.markedRead();
      expect(item.isUnread, isTrue);
      expect(read.isUnread, isFalse);
      expect(read.id, item.id);
    });

    test('an unknown type degrades without hiding the notification', () {
      expect(NotificationType.fromValue('something_new'),
          NotificationType.requestSubmitted);
      expect(NotificationType.fromValue(null),
          NotificationType.requestSubmitted);
    });
  });

  group('DashboardSummary', () {
    test('reads the function row', () {
      final summary = DashboardSummary.fromMap({
        'total_assets': 41,
        'available_assets': 12,
        'borrowed_assets': 7,
        'pending_requests': 3,
        'overdue_returns': 1,
        'upcoming_reservations': 4,
        'active_maintenance': 2,
      });
      expect(summary.totalAssets, 41);
      expect(summary.availableAssets, 12);
      expect(summary.borrowedAssets, 7);
      expect(summary.pendingRequests, 3);
      expect(summary.overdueReturns, 1);
      expect(summary.upcomingReservations, 4);
      expect(summary.activeMaintenance, 2);
    });

    test('counts tolerate bigints serialised as strings', () {
      final summary = DashboardSummary.fromMap({
        'total_assets': '41',
        'overdue_returns': '1',
      });
      expect(summary.totalAssets, 41);
      expect(summary.overdueReturns, 1);
      expect(summary.pendingRequests, 0);
    });
  });
}
