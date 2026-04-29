import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/meal_log.dart';
import '../../services/health_reading_service.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// Activity feed showing recent health events for a profile.
///
/// Displays readings AND meals in a timestamped timeline format,
/// used in the caregiver dashboard. Items are merged and sorted by
/// timestamp desc, then capped at 6 entries so the card stays compact.
///
/// Meals are shown with neutral, factual labels — no causation,
/// no clinical claim about the patient's glucose response.
class ActivityFeedCard extends StatelessWidget {
  final List<HealthReading> readings;
  final List<MealLog> meals;
  final bool isLoading;

  const ActivityFeedCard({
    super.key,
    required this.readings,
    this.meals = const [],
    this.isLoading = false,
  });

  /// Merges readings + meals into a single timeline (desc by timestamp).
  /// Uses a sealed wrapper so each row knows which kind it is and can
  /// render via the appropriate widget.
  List<_ActivityEntry> _mergedEntries() {
    final entries = <_ActivityEntry>[
      ...readings.map(_ReadingEntry.new),
      ...meals.map(_MealEntry.new),
    ];
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _mergedEntries().take(6).toList();

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.activityFeedTitle.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  l10n.noRecentActivity,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...entries.map(
              (e) => switch (e) {
                _ReadingEntry(:final reading) => _ActivityReadingItem(
                  reading: reading,
                ),
                _MealEntry(:final meal) => _ActivityMealItem(
                  meal: meal,
                  key: Key('activity_meal_${meal.id}'),
                ),
              },
            ),
        ],
      ),
    );
  }
}

sealed class _ActivityEntry {
  DateTime get timestamp;
}

class _ReadingEntry extends _ActivityEntry {
  final HealthReading reading;
  _ReadingEntry(this.reading);
  @override
  DateTime get timestamp => reading.readingTimestamp;
}

class _MealEntry extends _ActivityEntry {
  final MealLog meal;
  _MealEntry(this.meal);
  @override
  DateTime get timestamp => meal.timestamp;
}

class _ActivityReadingItem extends StatelessWidget {
  final HealthReading reading;

  const _ActivityReadingItem({required this.reading});

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(reading.readingType);
    final label = _labelForReading(reading);
    final time = _formatTime(reading.readingTimestamp);
    final statusColor = _statusColor(reading.statusFlag);

    return _TimelineRow(
      dotColor: statusColor,
      icon: icon,
      label: label,
      time: time,
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'blood_pressure':
        return Icons.favorite_outline;
      case 'glucose':
        return Icons.water_drop_outlined;
      case 'spo2':
        return Icons.air;
      case 'steps':
        return Icons.directions_walk;
      default:
        return Icons.monitor_heart_outlined;
    }
  }

  String _labelForReading(HealthReading r) {
    switch (r.readingType) {
      case 'blood_pressure':
        final sys = r.systolic?.toStringAsFixed(0) ?? '—';
        final dia = r.diastolic?.toStringAsFixed(0) ?? '—';
        return 'Blood Pressure: $sys/$dia mmHg';
      case 'glucose':
        final val = r.glucoseValue?.toStringAsFixed(0) ?? '—';
        return 'Glucose: $val mg/dL';
      case 'spo2':
        final val = r.spo2Value?.toStringAsFixed(0) ?? '—';
        return 'SpO2: $val%';
      case 'steps':
        final val = r.stepsCount ?? 0;
        return 'Steps: $val';
      default:
        return 'Reading logged';
    }
  }

  Color _statusColor(String? status) {
    if (status == null) return AppColors.textSecondary;
    final s = status.toLowerCase();
    if (s.contains('critical') || s.contains('stage 2')) {
      return AppColors.statusCritical;
    }
    if (s.contains('high') || s.contains('elevated') || s.contains('stage 1')) {
      return AppColors.statusElevated;
    }
    if (s.contains('low')) return AppColors.statusLow;
    return AppColors.statusNormal;
  }
}

class _ActivityMealItem extends StatelessWidget {
  final MealLog meal;

  const _ActivityMealItem({required this.meal, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mealType = _localizedMealType(meal.mealType, l10n);
    final category = (meal.userCorrectedCategory ?? meal.category).replaceAll(
      '_',
      ' ',
    );
    final dotColor = _impactColor(meal.glucoseImpact);
    final time = _formatTime(meal.timestamp);

    return _TimelineRow(
      dotColor: dotColor,
      icon: Icons.restaurant,
      label: '$mealType: $category',
      time: time,
    );
  }

  String _localizedMealType(String mealType, AppLocalizations l10n) {
    switch (mealType) {
      case 'BREAKFAST':
        return l10n.mealTypeBreakfast;
      case 'LUNCH':
        return l10n.mealTypeLunch;
      case 'SNACK':
        return l10n.mealTypeSnack;
      case 'DINNER':
        return l10n.mealTypeDinner;
      default:
        return mealType;
    }
  }

  /// Carb-load palette is intentionally non-clinical: never use
  /// `statusCritical` red here, otherwise meals visually equate to
  /// abnormal vitals on the activity timeline. Mirrors the rule in
  /// `history_screen.dart::_carbLoadColor`.
  Color _impactColor(String impact) {
    switch (impact) {
      case 'LOW':
        return AppColors.statusNormal;
      case 'MODERATE':
        return AppColors.amber;
      case 'HIGH':
        return AppColors.amber;
      case 'VERY_HIGH':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }
}

/// Shared row layout: timeline dot + connector line + icon + label + time.
class _TimelineRow extends StatelessWidget {
  final Color dotColor;
  final IconData icon;
  final String label;
  final String time;

  const _TimelineRow({
    required this.dotColor,
    required this.icon,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppColors.textSecondary.withValues(alpha: 0.2),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';

  // 12-hour clock: 0 → 12 AM, 12 → 12 PM, 13 → 1 PM
  final hour24 = local.hour;
  final h = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final ampm = hour24 >= 12 ? 'PM' : 'AM';
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month} $h:$min $ampm';
}
