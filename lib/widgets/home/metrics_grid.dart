import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/health_helpers.dart' as helpers;
import '../glass_card.dart';

/// 2x2 grid of individual metric tiles (BP, Sugar, Steps, BMI).
class MetricsGrid extends StatelessWidget {
  final Map<String, dynamic>? data;
  final int? profileId;
  final void Function({required String deviceType, required String btDeviceType}) onAddReading;
  final bool canEdit;

  const MetricsGrid({
    super.key,
    required this.data,
    required this.profileId,
    required this.onAddReading,
    this.canEdit = true,
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

    final bmi = (data?['bmi'] as num?)?.toDouble();
    final bmiCategory = data?['bmi_category'] as String?;

    final bpValue = lastBpSys != null && lastBpDia != null
        ? '${lastBpSys.toStringAsFixed(0)}/${lastBpDia.toStringAsFixed(0)}'
        : '—';
    final glucoseValue =
        lastGlucose != null ? '${lastGlucose.toStringAsFixed(0)} mg' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.individualMetricsSection.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: l10n.lastBP,
                value: bpValue,
                valueColor: helpers.statusTextColor(lastBpStatus),
                onAddTap: canEdit ? () => onAddReading(deviceType: 'blood_pressure', btDeviceType: 'Blood Pressure') : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: l10n.lastSugar,
                value: glucoseValue,
                valueColor: helpers.statusTextColor(lastGlucoseStatus),
                onAddTap: canEdit ? () => onAddReading(deviceType: 'glucose', btDeviceType: 'Glucose') : null,
              ),
            ),
          ],
        ),
        if (ageContextBp != null || ageContextGlucose != null) ...[
          const SizedBox(height: 8),
          ...[ ageContextBp, ageContextGlucose ].whereType<String>().map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: l10n.liveSteps,
                value: '—',
                valueColor: AppColors.textPrimary,
                addButtonColor: AppColors.primary,
                onAddTap: null, // Phase 8D
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BmiTile(
                bmi: bmi,
                category: bmiCategory,
                heightCm: (data?['profile_height'] as num?)?.toDouble(),
                weightKg: (data?['profile_weight'] as num?)?.toDouble(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color addButtonColor;
  final VoidCallback? onAddTap;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.valueColor,
    this.addButtonColor = AppColors.textPrimary,
    this.onAddTap,
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
                      color: addButtonColor,
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

class _BmiTile extends StatelessWidget {
  final double? bmi;
  final String? category;
  final double? heightCm;
  final double? weightKg;

  const _BmiTile({this.bmi, this.category, this.heightCm, this.weightKg});

  Color _bmiColor() {
    if (bmi == null) return AppColors.textSecondary;
    if (bmi! < 18.5) return AppColors.statusLow;
    if (bmi! < 25) return AppColors.statusNormal;
    if (bmi! < 30) return AppColors.statusElevated;
    return AppColors.statusCritical;
  }

  String? _tip() {
    if (bmi == null || heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final hm = heightCm! / 100.0;
    final hm2 = hm * hm;
    if (bmi! < 18.5) {
      final targetKg = (18.5 * hm2) - weightKg!;
      return 'Gain ${targetKg.toStringAsFixed(1)} kg to reach normal';
    } else if (bmi! >= 25 && bmi! < 30) {
      final targetKg = weightKg! - (24.9 * hm2);
      return 'Lose ${targetKg.toStringAsFixed(1)} kg to reach normal';
    } else if (bmi! >= 30) {
      final targetKg = weightKg! - (24.9 * hm2);
      return 'Lose ${targetKg.toStringAsFixed(1)} kg to reach normal';
    }
    return 'Healthy BMI — keep it up!';
  }

  @override
  Widget build(BuildContext context) {
    final color = _bmiColor();
    final displayValue = bmi != null ? bmi!.toStringAsFixed(1) : '—';
    final displayCategory = category ?? '';
    final tip = _tip();

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      margin: EdgeInsets.zero,
      color: bmi != null ? color.withValues(alpha: 0.08) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'BMI',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
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
              if (displayCategory.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    displayCategory,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (tip != null) ...[
            const SizedBox(height: 4),
            Text(
              tip,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontStyle: FontStyle.italic,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
