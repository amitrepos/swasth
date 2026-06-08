/// Intake time-of-day periods for medicine logging (NUO-127).
///
/// Mirrors [meal_type_detector.dart] — local device time drives defaults.
import '../l10n/app_localizations.dart';

const kMedicationPeriodMorningStartHour = 5;
const kMedicationPeriodMorningEndHour = 12;
const kMedicationPeriodAfternoonEndHour = 17;
const kMedicationPeriodEveningEndHour = 21;

const medicationIntakePeriods = ['MORNING', 'AFTERNOON', 'EVENING', 'NIGHT'];

const medicationPeriodAnchorHours = <String, int>{
  'MORNING': 8,
  'AFTERNOON': 14,
  'EVENING': 19,
  'NIGHT': 22,
};

/// Detects the current intake period from local device hour.
String detectMedicationIntakePeriod([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour >= kMedicationPeriodMorningStartHour &&
      hour < kMedicationPeriodMorningEndHour) {
    return 'MORNING';
  }
  if (hour >= kMedicationPeriodMorningEndHour &&
      hour < kMedicationPeriodAfternoonEndHour) {
    return 'AFTERNOON';
  }
  if (hour >= kMedicationPeriodAfternoonEndHour &&
      hour < kMedicationPeriodEveningEndHour) {
    return 'EVENING';
  }
  return 'NIGHT';
}

/// Combines a calendar date (local) with a period anchor hour → UTC for API.
DateTime takenAtFromDateAndPeriod(DateTime date, String period) {
  final hour = medicationPeriodAnchorHours[period] ?? 8;
  final local = DateTime(date.year, date.month, date.day, hour);
  return local.toUtc();
}

/// Local anchor datetime for display (approximate recorded time hint).
DateTime localAnchorDateTime(DateTime date, String period) {
  final hour = medicationPeriodAnchorHours[period] ?? 8;
  return DateTime(date.year, date.month, date.day, hour);
}

String medicationPeriodLabel(AppLocalizations l10n, String period) {
  switch (period) {
    case 'MORNING':
      return l10n.medicationsPeriodMorning;
    case 'AFTERNOON':
      return l10n.medicationsPeriodAfternoon;
    case 'EVENING':
      return l10n.medicationsPeriodEvening;
    case 'NIGHT':
      return l10n.medicationsPeriodNight;
    default:
      return period;
  }
}
