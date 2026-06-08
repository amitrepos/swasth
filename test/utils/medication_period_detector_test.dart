import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations_en.dart';
import 'package:swasth_app/utils/medication_period_detector.dart';

void main() {
  group('detectMedicationIntakePeriod', () {
    test('boundary hours map to correct period', () {
      expect(detectMedicationIntakePeriod(DateTime(2024, 1, 1, 0)), 'NIGHT');
      expect(detectMedicationIntakePeriod(DateTime(2024, 1, 1, 2)), 'NIGHT');
      expect(detectMedicationIntakePeriod(DateTime(2024, 1, 1, 4)), 'NIGHT');
      expect(detectMedicationIntakePeriod(DateTime(2024, 1, 1, 5)), 'MORNING');
      expect(
        detectMedicationIntakePeriod(DateTime(2024, 1, 1, 11, 59)),
        'MORNING',
      );
      expect(
        detectMedicationIntakePeriod(DateTime(2024, 1, 1, 12)),
        'AFTERNOON',
      );
      expect(
        detectMedicationIntakePeriod(DateTime(2024, 1, 1, 16, 59)),
        'AFTERNOON',
      );
      expect(detectMedicationIntakePeriod(DateTime(2024, 1, 1, 17)), 'EVENING');
      expect(
        detectMedicationIntakePeriod(DateTime(2024, 1, 1, 20, 59)),
        'EVENING',
      );
      expect(detectMedicationIntakePeriod(DateTime(2024, 1, 1, 21)), 'NIGHT');
      expect(
        detectMedicationIntakePeriod(DateTime(2024, 1, 1, 23, 59)),
        'NIGHT',
      );
    });
  });

  group('takenAtFromDateAndPeriod', () {
    test('NIGHT anchor uses 22:00 local on selected date', () {
      final date = DateTime(2024, 6, 15);
      final local = takenAtFromDateAndPeriod(date, 'NIGHT').toLocal();
      expect(local.year, 2024);
      expect(local.month, 6);
      expect(local.day, 15);
      expect(local.hour, 22);
      expect(local.minute, 0);
    });

    test('each period uses its anchor hour locally', () {
      final date = DateTime(2024, 3, 10);
      expect(localAnchorDateTime(date, 'MORNING').hour, 8);
      expect(localAnchorDateTime(date, 'AFTERNOON').hour, 14);
      expect(localAnchorDateTime(date, 'EVENING').hour, 19);
      expect(localAnchorDateTime(date, 'NIGHT').hour, 22);
    });

    test('returns UTC DateTime', () {
      final result = takenAtFromDateAndPeriod(DateTime(2024, 1, 1), 'MORNING');
      expect(result.isUtc, isTrue);
    });
  });

  group('medicationPeriodLabel', () {
    test('all valid periods return localized labels', () {
      final l10n = AppLocalizationsEn();
      const expected = {
        'MORNING': 'Morning',
        'AFTERNOON': 'Afternoon',
        'EVENING': 'Evening',
        'NIGHT': 'Night',
      };
      for (final entry in expected.entries) {
        expect(medicationPeriodLabel(l10n, entry.key), entry.value);
      }
    });

    test('unknown period returns raw value', () {
      final l10n = AppLocalizationsEn();
      expect(medicationPeriodLabel(l10n, 'UNKNOWN'), 'UNKNOWN');
    });
  });
}
