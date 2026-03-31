import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/health_helpers.dart' as helpers;
import '../glass_card.dart';

/// 2x2 grid of individual metric tiles (BP, Sugar, Steps, Armband).
class MetricsGrid extends StatelessWidget {
  final Map<String, dynamic>? data;
  final int? profileId;
  final void Function({required String deviceType, required String btDeviceType}) onAddReading;
  final VoidCallback onArmBandTap;
  final bool canEdit;

  const MetricsGrid({
    super.key,
    required this.data,
    required this.profileId,
    required this.onAddReading,
    required this.onArmBandTap,
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
              child: _ArmBandTile(
                isConnected: false,
                onTap: onArmBandTap,
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

class _ArmBandTile extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onTap;

  const _ArmBandTile({required this.isConnected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        margin: EdgeInsets.zero,
        color: isConnected ? AppColors.success.withValues(alpha: 0.08) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ARM BAND STATUS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConnected ? 'ACTIVE SYNC' : 'NOT CONNECTED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isConnected ? AppColors.success : AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
