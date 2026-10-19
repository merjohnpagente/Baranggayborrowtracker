import 'package:flutter_test/flutter_test.dart';

import 'package:barangay_borrow_tracker/data/models/asset.dart';
import 'package:barangay_borrow_tracker/data/models/borrow_request.dart';

void main() {
  group('AssetStatus', () {
    test('only available and reserved can be requested', () {
      expect(AssetStatus.available.canRequest, isTrue);
      expect(AssetStatus.reserved.canRequest, isTrue);
      expect(AssetStatus.borrowed.canRequest, isFalse);
      expect(AssetStatus.maintenance.canRequest, isFalse);
      expect(AssetStatus.retired.canRequest, isFalse);
    });

    test('an unknown status degrades to available rather than throwing', () {
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
  });

  group('Asset.fromMap', () {
    test('reads a full row', () {
      final asset = Asset.fromMap({
        'id': 'a1',
        'code': 'VEH-001',
        'name': 'Service Vehicle',
        'status': 'borrowed',
        'condition': 'fair',
        'location': 'Barangay Hall',
      });
      expect(asset.code, 'VEH-001');
      expect(asset.status, AssetStatus.borrowed);
      expect(asset.condition, AssetCondition.fair);
      expect(asset.isAvailable, isFalse);
    });

    test('missing optional fields fall back without throwing', () {
      final asset = Asset.fromMap({'id': 'a2'});
      expect(asset.code, '');
      expect(asset.name, 'Unnamed asset');
      expect(asset.status, AssetStatus.available);
      expect(asset.location, isNull);
      expect(asset.depositAmount, 0);
    });

    test('deposit tolerates a numeric string from Postgres', () {
      final asset = Asset.fromMap({'id': 'a3', 'deposit_amount': '250.50'});
      expect(asset.depositAmount, 250.50);
    });

    test('isAvailable is true only for an available asset', () {
      Asset build(String status) =>
          Asset.fromMap({'id': 'x', 'status': status});
      expect(build('available').isAvailable, isTrue);
      expect(build('reserved').isAvailable, isFalse);
      expect(build('maintenance').isAvailable, isFalse);
    });
  });

  group('RequestStatus', () {
    test('open means not yet finished', () {
      expect(RequestStatus.pending.isOpen, isTrue);
      expect(RequestStatus.approved.isOpen, isTrue);
      expect(RequestStatus.released.isOpen, isTrue);
      expect(RequestStatus.returned.isOpen, isFalse);
      expect(RequestStatus.declined.isOpen, isFalse);
      expect(RequestStatus.cancelled.isOpen, isFalse);
    });

    test('active means the decision has been made', () {
      expect(RequestStatus.pending.isActive, isFalse);
      expect(RequestStatus.approved.isActive, isTrue);
      expect(RequestStatus.released.isActive, isTrue);
    });

    test('unknown status degrades to pending', () {
      expect(RequestStatus.fromValue('brand_new_state'), RequestStatus.pending);
      expect(RequestStatus.fromValue(null), RequestStatus.pending);
    });
  });

  group('BorrowRequest', () {
    Map<String, dynamic> row({
      String status = 'pending',
      String borrow = '2026-05-01',
      String ret = '2026-05-03',
    }) =>
        {
          'id': 'r1',
          'reference_no': 'BR-0001',
          'asset_id': 'a1',
          'user_id': 'u1',
          'purpose': 'Barangay outreach',
          'status': status,
          'borrow_date': borrow,
          'return_date': ret,
        };

    test('reads dates and computes the loan length', () {
      final request = BorrowRequest.fromMap(row());
      expect(request.borrowDate, DateTime(2026, 5, 1));
      expect(request.returnDate, DateTime(2026, 5, 3));
      // Inclusive: borrowed on the 1st, due on the 3rd is three days.
      expect(request.totalDays, 3);
    });

    test('a returned request is not late however old the dates are', () {
      final request = BorrowRequest.fromMap(
        row(status: 'returned', borrow: '2020-01-01', ret: '2020-01-02'),
      );
      expect(request.isLate, isFalse);
    });

    test('the overdue flag is honoured even before the clock catches up', () {
      final map = row(status: 'released')..['overdue'] = true;
      expect(BorrowRequest.fromMap(map).isLate, isTrue);
    });

    test('a released request past its return date is late', () {
      final request = BorrowRequest.fromMap(
        row(status: 'released', borrow: '2020-01-01', ret: '2020-01-02'),
      );
      expect(request.isLate, isTrue);
    });

    test('missing timestamps do not throw', () {
      final request = BorrowRequest.fromMap({
        'id': 'r2',
        'reference_no': 'BR-0002',
        'asset_id': 'a1',
        'user_id': 'u1',
        'purpose': 'No dates',
      });
      expect(request.status, RequestStatus.pending);
      expect(request.referenceNo, '—');
    });
  });
}