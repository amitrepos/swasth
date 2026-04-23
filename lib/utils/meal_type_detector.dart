/// Shared utility for detecting meal type based on current local time.
///
/// Uses local device time (not UTC) so that meal detection is correct
/// for users in any timezone, including IST (UTC+5:30).
///
/// The hour thresholds are calibrated for local time:
/// - Before 11:00 → BREAKFAST
/// - Before 15:00 → LUNCH
/// - Before 18:00 → SNACK
/// - 18:00 and later → DINNER

const kBreakfastEndHour = 11;
const kLunchEndHour = 15;
const kSnackEndHour = 18;

/// Detects the current meal type based on local time.
String detectMealType() {
  final hour = DateTime.now().hour;
  if (hour < kBreakfastEndHour) return 'BREAKFAST';
  if (hour < kLunchEndHour) return 'LUNCH';
  if (hour < kSnackEndHour) return 'SNACK';
  return 'DINNER';
}
