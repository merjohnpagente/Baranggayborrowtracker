import 'package:flutter_test/flutter_test.dart';

import 'package:barangay_borrow_tracker/core/utils/formatters.dart';
import 'package:barangay_borrow_tracker/core/utils/qr_payload.dart';
import 'package:barangay_borrow_tracker/core/utils/validators.dart';

void main() {
  group('QrPayload', () {
    test('round-trips an asset code', () {
      final payload = QrPayload.forAsset('a1b2');
      final parsed = QrPayload.parse(payload);
      expect(parsed, isNotNull);
      expect(parsed!.type, 'asset');
      expect(parsed.id, 'a1b2');
    });

    test('round-trips a request code', () {
      final parsed = QrPayload.parse(QrPayload.forRequest('r9'));
      expect(parsed!.type, 'request');
      expect(parsed.id, 'r9');
    });

    test('rejects anything that is not one of ours', () {
      expect(QrPayload.parse(null), isNull);
      expect(QrPayload.parse('https://example.test'), isNull);
      expect(QrPayload.parse('XYZ|asset|a1'), isNull);
      expect(QrPayload.parse('BBT|asset'), isNull);
      // A barcode from a product packet must not be mistaken for an asset.
      expect(QrPayload.parse('4801234567890'), isNull);
    });

    test('caption prints the identifier in upper case', () {
      expect(QrPayload.caption(QrPayload.forAsset('ab-12')), 'AB-12');
    });
  });

  group('Fmt', () {
    test('counts both ends of a loan', () {
      expect(
        Fmt.inclusiveDays(DateTime(2026, 5, 1), DateTime(2026, 5, 1)),
        1,
      );
      expect(
        Fmt.inclusiveDays(DateTime(2026, 5, 1), DateTime(2026, 5, 3)),
        3,
      );
    });

    test('countdown reads naturally in both directions', () {
      final today = DateTime.now();
      expect(Fmt.countdown(today), 'due today');
      expect(Fmt.countdown(today.add(const Duration(days: 1))), 'due tomorrow');
      expect(Fmt.countdown(today.subtract(const Duration(days: 2))),
          '2 days overdue');
    });
  });

  group('Validators', () {
    test('email requires an @ and a dotted domain', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('juan@example.test'), isNull);
    });

    test('phone is optional but not nonsense when supplied', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('abc'), isNotNull);
      expect(Validators.phone('0917 123 4567'), isNull);
    });

    test('purpose needs enough detail to be actionable', () {
      expect(Validators.minimumLength('ball', 10, 'Purpose'), isNotNull);
      expect(
        Validators.minimumLength('Basketball league finals', 10, 'Purpose'),
        isNull,
      );
    });
  });
}
