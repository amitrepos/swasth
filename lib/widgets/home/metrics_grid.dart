import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/health_helpers.dart' as helpers;
import '../../utils/metric_ranges.dart';
import '../glass_card.dart';
import 'metric_info_sheet.dart';

class MetricsGrid extends StatelessWidget {
  final Map<String, dynamic>? data;
  final int? profileId;
  final void Function({
    required String deviceType,
    required String btDeviceType,
  })
  onAddReading;
  final bool canEdit;

  /// BMI fields (passed from home screen's health-score data).
  final double? bmi;
  final String? bmiCategory;
  final double? heightCm;
  final double? weightKg;

  /// Profile context for personalising the metric-info reference ranges.
  final int? age;
  final List<String>? medicalConditions;

  const MetricsGrid({
    super.key,
    required this.data,
    required this.profileId,
    required this.onAddReading,
    this.canEdit = true,
    this.bmi,
    this.bmiCategory,
    this.heightCm,
    this.weightKg,
    this.age,
    this.medicalConditions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final lastBpSys = (data?['last_bp_systolic'] as num?)?.toDouble();
    final lastBpDia = (data?['last_bp_diastolic'] as num?)?.toDouble();
    final lastBpStatus = data?['last_bp_status'] as String?;
    final lastGlucose = (data?['last_glucose_value'] as num?)?.toDouble();
    final lastGlucoseStatus = data?['last_glucose_status'] as String?;
    final lastGlucoseMealContext = glucoseMealContextFromString(
      data?['last_glucose_meal_context'] as String?,
    );
    final ageContextBp = data?['age_context_bp'] as String?;
    final ageContextGlucose = data?['age_context_glucose'] as String?;

    // Fallback values from data if not explicitly provided
    final effectiveBmi = bmi ?? (data?['bmi'] as num?)?.toDouble();
    final effectiveBmiCategory =
        bmiCategory ?? data?['bmi_category'] as String?;
    final effectiveHeight =
        heightCm ?? (data?['profile_height'] as num?)?.toDouble();
    final effectiveWeight =
        weightKg ??
        (data?['last_weight_value'] as num?)?.toDouble() ??
        (data?['profile_weight'] as num?)?.toDouble();

    // Steps data
    // For new users or days without step data, default to 0 instead of null
    final todaySteps = (data?['today_steps_count'] as num?)?.toInt() ?? 0;
    final stepsGoal = (data?['today_steps_goal'] as num?)?.toInt() ?? 7500;

    // Personalisation inputs for metric-info sheets.
    final effectiveAge = age ?? (data?['profile_age'] as num?)?.toInt();
    final effectiveConditions =
        medicalConditions ??
        (data?['medical_conditions'] as List?)?.cast<String>() ??
        const <String>[];

    final bpValue = lastBpSys != null && lastBpDia != null
        ? '${lastBpSys.toStringAsFixed(0)}/${lastBpDia.toStringAsFixed(0)}'
        : '—';
    String shortGlucoseContext(GlucoseMealContext c) {
      switch (c) {
        case GlucoseMealContext.fasting:
          return ' · ${l10n.contextFastingShort}';
        case GlucoseMealContext.beforeMeal:
          return ' · ${l10n.contextBeforeMealShort}';
        case GlucoseMealContext.postMeal:
          return ' · ${l10n.contextPostMealShort}';
        case GlucoseMealContext.random:
          return ' · ${l10n.contextRandomShort}';
        case GlucoseMealContext.unknown:
          return '';
      }
    }

    final lastGlucoseValue = lastGlucose != null
        ? '${lastGlucose.toStringAsFixed(0)} mg${shortGlucoseContext(lastGlucoseMealContext)}'
        : '—';

    // Weight & SpO2
    final lastWeight = (data?['last_weight_value'] as num?)?.toDouble();

    final weightValue = lastWeight != null
        ? '${lastWeight.toStringAsFixed(1)} kg'
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.vitalsSection.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        // Row 1: BP + Sugar
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: l10n.lastBP,
                value: bpValue,
                valueColor: helpers.statusTextColor(lastBpStatus),
                infoIconKey: const Key('bp_info_button'),
                onInfoTap: () => showMetricInfoSheet(
                  context,
                  buildBpSpec(
                    sys: lastBpSys,
                    dia: lastBpDia,
                    age: effectiveAge,
                    conditions: effectiveConditions,
                  ),
                ),
                onAddTap: canEdit
                    ? () => onAddReading(
                        deviceType: 'blood_pressure',
                        btDeviceType: 'Blood Pressure',
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: l10n.lastSugar,
                value: lastGlucoseValue,
                valueColor: helpers.statusTextColor(lastGlucoseStatus),
                infoIconKey: const Key('sugar_info_button'),
                onInfoTap: () => showMetricInfoSheet(
                  context,
                  buildGlucoseSpec(
                    mgdl: lastGlucose,
                    age: effectiveAge,
                    conditions: effectiveConditions,
                    mealContext: lastGlucoseMealContext,
                  ),
                ),
                onAddTap: canEdit
                    ? () => onAddReading(
                        deviceType: 'glucose',
                        btDeviceType: 'Glucose',
                      )
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2: BMI + Steps — IntrinsicHeight forces both cards
        // to match the taller sibling's height so they look uniform.
        IntrinsicHeight(
         child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _BmiTile(
                bmi: effectiveBmi,
                category: effectiveBmiCategory,
                heightCm: effectiveHeight,
                weightKg: effectiveWeight,
                weightDisplay: weightValue,
                onInfoTap: () => showMetricInfoSheet(
                  context,
                  buildBmiSpec(bmi: effectiveBmi, age: effectiveAge),
                ),
                onAddWeight: canEdit
                    ? () => onAddReading(
                        deviceType: 'weight',
                        btDeviceType: 'Weight',
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StepsTile(
                label: l10n.lastSteps,
                count: todaySteps,
                goal: stepsGoal,
                subtitle: l10n.viaPhone,
                onInfoTap: () => showMetricInfoSheet(
                  context,
                  buildStepsSpec(
                    count: todaySteps,
                    age: effectiveAge,
                    conditions: effectiveConditions,
                  ),
                ),
              ),
            ),
          ],
         ),
        ),
        if (ageContextBp != null || ageContextGlucose != null) ...[
          const SizedBox(height: 8),
          ...[ageContextBp, ageContextGlucose].whereType<String>().map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback? onAddTap;
  final VoidCallback? onInfoTap;
  final Key? infoIconKey;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.valueColor,
    this.onAddTap,
    this.onInfoTap,
    this.infoIconKey,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (onInfoTap != null)
                _InfoIconButton(iconKey: infoIconKey, onTap: onInfoTap!),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (onAddTap != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Steps tile with progress bar showing % of daily goal.
class _StepsTile extends StatelessWidget {
  final String label;
  final int? count;
  final int goal;
  final String? subtitle;
  final VoidCallback? onInfoTap;

  const _StepsTile({
    required this.label,
    required this.count,
    required this.goal,
    this.subtitle,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    // count should never be null now since we default to 0 in MetricsGrid
    final displayValue = count != null ? _formatSteps(count!) : '—';
    final progress = count != null && goal > 0
        ? (count! / goal).clamp(0.0, 1.0)
        : 0.0;
    final pct = (progress * 100).toInt();

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (onInfoTap != null)
                _InfoIconButton(
                  iconKey: const Key('steps_info_button'),
                  onTap: onInfoTap!,
                ),
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: count != null && count! > 0
                  ? AppColors.statusNormal
                  : AppColors.textSecondary,
            ),
          ),
          // Always show progress bar, even for 0 steps
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE0E5EA),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.statusNormal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$pct% of ${_formatSteps(goal)}',
            style: const TextStyle(fontSize: 8, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return '$steps';
  }
}

/// BMI tile — same shape/size as Steps tile.
class _BmiTile extends StatelessWidget {
  final double? bmi;
  final String? category;
  final double? heightCm;
  final double? weightKg;
  final String weightDisplay;
  final VoidCallback? onAddWeight;
  final VoidCallback? onInfoTap;

  const _BmiTile({
    this.bmi,
    this.category,
    this.heightCm,
    this.weightKg,
    required this.weightDisplay,
    this.onAddWeight,
    this.onInfoTap,
  });

  Color _bmiColor() {
    if (bmi == null) return AppColors.textSecondary;
    if (bmi! < 18.5) return AppColors.statusLow;
    if (bmi! < 25) return AppColors.statusNormal;
    if (bmi! < 30) return AppColors.statusElevated;
    return AppColors.statusCritical;
  }

  String? _tip(AppLocalizations l10n) {
    if (bmi == null || heightCm == null || weightKg == null || heightCm! <= 0) {
      return null;
    }
    final hm = heightCm! / 100.0;
    final hm2 = hm * hm;
    if (bmi! < 18.5) {
      final targetKg = (18.5 * hm2) - weightKg!;
      return l10n.bmiTipGain(targetKg.toStringAsFixed(1));
    } else if (bmi! >= 25) {
      final targetKg = weightKg! - (24.9 * hm2);
      return l10n.bmiTipLose(targetKg.toStringAsFixed(1));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _bmiColor();
    final displayValue = bmi != null ? bmi!.toStringAsFixed(1) : '—';
    final displayCategory = category ?? '';
    final tip = _tip(l10n);

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: BMI
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.metricBmi.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      if (onInfoTap != null) ...[
                        const SizedBox(width: 6),
                        _InfoIconButton(
                          iconKey: const Key('bmi_info_button'),
                          onTap: onInfoTap!,
                        ),
                      ],
                    ],
                  ),
                  if (displayCategory.isNotEmpty)
                    Text(
                      displayCategory,
                      style: TextStyle(fontSize: 8, color: color),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        displayValue,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Right side: Weight — vertical stack, no horizontal
              // competition with BMI so it never overflows.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 1. Heading
                  Text(
                    AppLocalizations.of(context)!.weightLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 2. Add button (standalone, below heading)
                  if (onAddWeight != null)
                    GestureDetector(
                      onTap: onAddWeight,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  // 3. Actual weight value below the button
                  Text(
                    weightDisplay,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (tip != null) ...[
            const SizedBox(height: 6),
            Text(
              tip,
              style: TextStyle(
                fontSize: 8,
                color: color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small "?" button used on every Vitals tile to reveal the metric info sheet.
/// Styled to mirror the wellness-score "?" — circular tinted background so it
/// is visible at arm's length and easy to tap (24×24 hit area).
class _InfoIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final Key? iconKey;

  const _InfoIconButton({required this.onTap, this.iconKey});

  static const double _visibleSize = 24;

  @override
  Widget build(BuildContext context) {
    // 44×44 hit area (WCAG 2.5.5), with a smaller visible circle inside it
    // so the tile is not visually crowded.
    return Semantics(
      button: true,
      label: 'Learn about this measurement',
      child: SizedBox(
        width: 44,
        height: 44,
        child: GestureDetector(
          key: iconKey,
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Container(
              width: _visibleSize,
              height: _visibleSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.40),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.help_outline,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
