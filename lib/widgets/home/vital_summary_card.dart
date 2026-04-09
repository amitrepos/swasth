import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/health_helpers.dart' as helpers;
import '../glass_card.dart';

/// Shows 90-day vital averages (BP, Sugar, SpO2, Steps) with trend indicators.
class VitalSummaryCard extends StatelessWidget {
  final Map<String, dynamic>? data;

  const VitalSummaryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final avgSys = (data?['avg_systolic_90d'] as num?)?.toDouble();
    final avgDia = (data?['avg_diastolic_90d'] as num?)?.toDouble();
    final prevAvgSys = (data?['prev_avg_systolic_90d'] as num?)?.toDouble();
    final avgGlucose = (data?['avg_glucose_90d'] as num?)?.toDouble();
    final prevAvgGlucose = (data?['prev_avg_glucose_90d'] as num?)?.toDouble();
    final avgSpo2 = (data?['avg_spo2_90d'] as num?)?.toDouble();
    final avgSteps = (data?['avg_steps_90d'] as num?)?.toDouble();

    final bpDays = (data?['bp_data_days'] as num?)?.toInt() ?? 0;
    final glucoseDays = (data?['glucose_data_days'] as num?)?.toInt() ?? 0;
    final spo2Days = (data?['spo2_data_days'] as num?)?.toInt() ?? 0;
    final stepsDays = (data?['steps_data_days'] as num?)?.toInt() ?? 0;

    final bpAvgLabel = bpDays > 0 ? '$bpDays-day' : l10n.ninetyDayAvg;
    final glucoseAvgLabel = glucoseDays > 0
        ? '$glucoseDays-day'
        : l10n.ninetyDayAvg;
    final spo2AvgLabel = spo2Days > 0 ? '$spo2Days-day' : 'Avg';
    final stepsAvgLabel = stepsDays > 0 ? '$stepsDays-day' : 'Avg';

    final bpLabel = avgSys != null && avgDia != null
        ? '${avgSys.toStringAsFixed(0)}/${avgDia.toStringAsFixed(0)}'
        : '—';
    final glucoseLabel = avgGlucose != null
        ? '${avgGlucose.toStringAsFixed(0)} mg'
        : '—';
    final spo2Label = avgSpo2 != null ? '${avgSpo2.toStringAsFixed(1)}%' : '—';
    final stepsLabel = avgSteps != null
        ? '${(avgSteps / 1000).toStringAsFixed(1)}k'
        : '—';

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.trendsSection} \u00b7 ${l10n.ninetyDayAvg}'.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _VitalTile(
                  label: 'BP',
                  subLabel: bpAvgLabel,
                  value: bpLabel,
                  trendLabel: helpers.trendLabel(
                    avgSys,
                    prevAvgSys,
                    lowerIsBetter: true,
                  ),
                  trendColor: helpers.trendColor(
                    avgSys,
                    prevAvgSys,
                    lowerIsBetter: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _VitalTile(
                  label: 'SUGAR',
                  subLabel: glucoseAvgLabel,
                  value: glucoseLabel,
                  trendLabel: helpers.trendLabel(
                    avgGlucose,
                    prevAvgGlucose,
                    lowerIsBetter: true,
                  ),
                  trendColor: helpers.trendColor(
                    avgGlucose,
                    prevAvgGlucose,
                    lowerIsBetter: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _VitalTile(
                  label: 'SpO2',
                  subLabel: spo2AvgLabel,
                  value: spo2Label,
                  trendLabel: l10n.trendStable,
                  trendColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _VitalTile(
                  label: 'STEPS',
                  subLabel: stepsAvgLabel,
                  value: stepsLabel,
                  trendLabel: l10n.trendStable,
                  trendColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VitalTile extends StatelessWidget {
  final String label;
  final String subLabel;
  final String value;
  final String trendLabel;
  final Color trendColor;

  const _VitalTile({
    required this.label,
    required this.subLabel,
    required this.value,
    required this.trendLabel,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          Text(
            subLabel,
            style: const TextStyle(
              fontSize: 7,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            trendLabel,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}
