import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/health_helpers.dart' as helpers;
import '../glass_card.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final lastBpSys = (data?['last_bp_systolic'] as num?)?.toDouble();
    final lastBpDia = (data?['last_bp_diastolic'] as num?)?.toDouble();
    final lastBpStatus = data?['last_bp_status'] as String?;
    final lastGlucose = (data?['last_glucose_value'] as num?)?.toDouble();
    final lastGlucoseStatus = data?['last_glucose_status'] as String?;
    final ageContextBp = data?['age_context_bp'] as String?;
    final ageContextGlucose = data?['age_context_glucose'] as String?;
    
    // Fallback values from data if not explicitly provided
    final effectiveBmi = bmi ?? (data?['bmi'] as num?)?.toDouble();
    final effectiveBmiCategory = bmiCategory ?? data?['bmi_category'] as String?;
    final effectiveHeight = heightCm ?? (data?['profile_height'] as num?)?.toDouble();
    final effectiveWeight = weightKg ?? (data?['last_weight_value'] as num?)?.toDouble() ?? (data?['profile_weight'] as num?)?.toDouble();

    // Steps data
    final todaySteps = (data?['today_steps_count'] as num?)?.toInt();
    final stepsGoal = (data?['today_steps_goal'] as num?)?.toInt() ?? 7500;

    // DEBUG: Print steps data to console
    debugPrint('MetricsGrid - Steps Data: todaySteps=$todaySteps, stepsGoal=$stepsGoal');
    debugPrint('MetricsGrid - Full data keys: ${data?.keys.toList()}');

    final bpValue = lastBpSys != null && lastBpDia != null
        ? '${lastBpSys.toStringAsFixed(0)}/${lastBpDia.toStringAsFixed(0)}'
        : '—';
    final lastGlucoseValue = lastGlucose != null
        ? '${lastGlucose.toStringAsFixed(0)} mg'
        : '—';

    // Weight & SpO2
    final lastWeight = (data?['last_weight_value'] as num?)?.toDouble();
    final avgWeight90d = (data?['avg_weight_90d'] as num?)?.toDouble();
    final lastSpo2 = (data?['last_spo2_value'] as num?)?.toDouble();
    final lastSpo2Status = data?['last_spo2_status'] as String?;

    final weightValue = lastWeight != null
        ? '${lastWeight.toStringAsFixed(1)} kg'
        : '—';
    final spo2Value = lastSpo2 != null
        ? '${lastSpo2.toStringAsFixed(0)}%'
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
        // Row 2: BMI + Steps
        Row(
          children: [
            Expanded(
              child: _BmiTile(
                bmi: effectiveBmi,
                category: effectiveBmiCategory,
                heightCm: effectiveHeight,
                weightKg: effectiveWeight,
                weightDisplay: weightValue,
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
              ),
            ),
          ],
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
  final String? subtitle;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.valueColor,
    this.onAddTap,
    this.subtitle,
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
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
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

  const _StepsTile({
    required this.label,
    required this.count,
    required this.goal,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
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
              color: count != null
                  ? AppColors.statusNormal
                  : AppColors.textSecondary,
            ),
          ),
          if (count != null) ...[
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
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textSecondary,
              ),
            ),
          ],
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

  const _BmiTile({
    this.bmi,
    this.category,
    this.heightCm,
    this.weightKg,
    required this.weightDisplay,
    this.onAddWeight,
  });

  Color _bmiColor() {
    if (bmi == null) return AppColors.textSecondary;
    if (bmi! < 18.5) return AppColors.statusLow;
    if (bmi! < 25) return AppColors.statusNormal;
    if (bmi! < 30) return AppColors.statusElevated;
    return AppColors.statusCritical;
  }

  String? _tip() {
    if (bmi == null || heightCm == null || weightKg == null || heightCm! <= 0) {
      return null;
    }
    final hm = heightCm! / 100.0;
    final hm2 = hm * hm;
    if (bmi! < 18.5) {
      final targetKg = (18.5 * hm2) - weightKg!;
      return 'Gain ${targetKg.toStringAsFixed(1)} kg';
    } else if (bmi! >= 25) {
      final targetKg = weightKg! - (24.9 * hm2);
      return 'Lose ${targetKg.toStringAsFixed(1)} kg';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color = _bmiColor();
    final displayValue = bmi != null ? bmi!.toStringAsFixed(1) : '—';
    final displayCategory = category ?? '';
    final tip = _tip();

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
                  Text(
                    'BMI',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
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
              // Right side: Weight
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'WEIGHT',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        weightDisplay,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (onAddWeight != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onAddWeight,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
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
