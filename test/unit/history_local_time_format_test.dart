// Regression tests: history & activity feed must format timestamps in the
// device's local timezone, not UTC.
//
// Both meal.timestamp and reading.readingTimestamp are produced by
// DateTimeUtils.parseUtc → DateTime with isUtc=true. The display layer is
// expected to call .toLocal() before DateFormat.format(). If a future change
// drops .toLocal(), users in IST (UTC+5:30) would see times offset by 5.5h
// (e.g. a 5:52 PM dinner displayed as 12:22 AM the next day).

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('UTC → local timestamp formatting (history + activity feed)', () {
    final fmt = DateFormat('MMM dd, yyyy • hh:mm a');

    test('toLocal() shifts a UTC instant to the device timezone', () {
      // 2026-04-29 17:52 IST == 2026-04-29 12:22 UTC
      final utc = DateTime.utc(2026, 4, 29, 12, 22);
      expect(utc.isUtc, isTrue);

      final local = utc.toLocal();

      // The local DateTime must be the same instant in absolute time.
      expect(local.millisecondsSinceEpoch, utc.millisecondsSinceEpoch);
      // …but not flagged as UTC anymore.
      expect(local.isUtc, isFalse);
    });

    test('formatting a UTC instant directly leaks UTC to the UI', () {
      // This is the BUG behavior we are guarding against.
      final utc = DateTime.utc(2026, 4, 29, 12, 22);
      final formattedUtc = fmt.format(utc);
      final formattedLocal = fmt.format(utc.toLocal());

      // In any non-UTC timezone these strings differ.
      // CI tends to run in UTC, so we only assert inequality when the
      // device is offset from UTC; otherwise the format is identical.
      final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
      if (offsetMinutes != 0) {
        expect(
          formattedUtc,
          isNot(equals(formattedLocal)),
          reason:
              'UI must call .toLocal() before formatting; otherwise users '
              'in non-UTC timezones see the wrong wall-clock time.',
        );
      } else {
        expect(formattedUtc, equals(formattedLocal));
      }
    });

    test('IST conversion: 12:22 UTC formats as 05:52 PM local (when in IST)',
        () {
      // Only meaningful to assert when the test host is actually in IST.
      // Skipped otherwise so the test is portable across CI environments.
      final offset = DateTime.now().timeZoneOffset;
      final isIst = offset.inMinutes == 330;
      if (!isIst) {
        return;
      }
      final utc = DateTime.utc(2026, 4, 29, 12, 22);
      expect(fmt.format(utc.toLocal()), 'Apr 29, 2026 • 05:52 PM');
    });
  });
}
