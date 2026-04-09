import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/health_reading_service.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// Activity feed showing recent health events for a profile.
///
/// Displays readings and meals in a timestamped timeline format,
/// used in the caregiver dashboard.
class ActivityFeedCard extends StatelessWidget {
  final List<HealthReading> readings;
  final bool isLoading;

  const ActivityFeedCard({
    super.key,
    required this.readings,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
          else if (readings.isEmpty)
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
            ...readings.take(6).map((r) => _ActivityItem(reading: r)),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final HealthReading reading;

  const _ActivityItem({required this.reading});

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(reading.readingType);
    final label = _labelForReading(reading);
    final time = _formatTime(reading.readingTimestamp);
    final statusColor = _statusColor(reading.statusFlag);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
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
          // Icon
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          // Content
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';

    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $h:$min $ampm';
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
