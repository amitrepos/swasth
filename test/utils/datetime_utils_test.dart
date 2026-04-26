import 'package:flutter_test/flutter_test.dart';
import '../../lib/utils/datetime_utils.dart';

void main() {
  group('DateTimeUtils.parseUtc', () {
    test('naive string (no suffix) is treated as UTC and converted to local', () {
      final result = DateTimeUtils.parseUtc('2026-04-25T10:00:00');
      final expected = DateTime.utc(2026, 4, 25, 10, 0, 0).toLocal();
      expect(result, equals(expected));
    });

    test('string ending in Z is parsed as UTC and converted to local', () {
      final result = DateTimeUtils.parseUtc('2026-04-25T10:00:00Z');
      final expected = DateTime.utc(2026, 4, 25, 10, 0, 0).toLocal();
      expect(result, equals(expected));
    });

    test('string with +00:00 offset is parsed and converted to local', () {
      final result = DateTimeUtils.parseUtc('2026-04-25T10:00:00+00:00');
      final expected = DateTime.utc(2026, 4, 25, 10, 0, 0).toLocal();
      expect(result, equals(expected));
    });

    test('null returns a value close to DateTime.now()', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final result = DateTimeUtils.parseUtc(null);
      final after = DateTime.now().add(const Duration(seconds: 1));
      expect(result.isAfter(before), isTrue);
      expect(result.isBefore(after), isTrue);
    });

    test('result is always local (isUtc == false)', () {
      expect(DateTimeUtils.parseUtc('2026-04-25T10:00:00Z').isUtc, isFalse);
      expect(DateTimeUtils.parseUtc('2026-04-25T10:00:00').isUtc, isFalse);
      expect(DateTimeUtils.parseUtc('2026-04-25T10:00:00+00:00').isUtc, isFalse);
    });
  });
}
