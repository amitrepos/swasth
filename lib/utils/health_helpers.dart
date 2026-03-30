import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Data class for the wellness status flag shown on the health score card.
class StatusFlagData {
  final String label;
  final String? subLabel;
  final Color color;
  final String emoji;

  const StatusFlagData({
    required this.label,
    this.subLabel,
    required this.color,
    required this.emoji,
  });
}

/// Returns the arc color for a health score ring.
Color scoreArcColor(int score) {
  if (score >= 70) return AppColors.success;
  if (score >= 40) return AppColors.amber;
  return AppColors.danger;
}

/// Returns a semantic text color for a clinical status string.
Color statusTextColor(String? status) {
  if (status == null) return AppColors.textPrimary;
  if (status == 'NORMAL') return AppColors.success;
  if (status == 'ELEVATED' || status == 'HIGH - STAGE 1') return AppColors.amber;
  if (status.contains('HIGH') || status == 'CRITICAL') return AppColors.danger;
  return AppColors.textPrimary;
}

/// Builds a human-readable trend label like "↑ 5%" from two values.
String trendLabel(double? current, double? previous,
    {bool lowerIsBetter = true}) {
  if (current == null || previous == null || previous == 0) return 'Stable';
  final pct = ((current - previous) / previous * 100).abs();
  if (pct < 2) return 'Stable';
  final increasing = current > previous;
  final arrow = increasing ? '↑' : '↓';
  return '$arrow ${pct.toStringAsFixed(0)}%';
}

/// Returns green/red/grey depending on whether the trend is beneficial.
Color trendColor(double? current, double? previous,
    {bool lowerIsBetter = true}) {
  if (current == null || previous == null || previous == 0) {
    return AppColors.textSecondary;
  }
  final pct = ((current - previous) / previous * 100).abs();
  if (pct < 2) return AppColors.textSecondary;
  final increasing = current > previous;
  final isGood = lowerIsBetter ? !increasing : increasing;
  return isGood ? AppColors.success : AppColors.danger;
}

/// Formats an ISO timestamp into a short "Updated 3:04 PM" or "Mar 5" string.
String formatLastLogged(String? isoString) {
  if (isoString == null) return '';
  try {
    final dt = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Updated ${DateFormat('h:mm a').format(dt)}';
    }
    return DateFormat('MMM d').format(dt);
  } catch (_) {
    return '';
  }
}

/// Maps streak days to gamification points.
int streakToPoints(int streak) {
  if (streak >= 30) return 1500;
  if (streak >= 14) return 700;
  if (streak >= 7) return 300;
  if (streak >= 3) return 100;
  if (streak >= 1) return 10;
  return 0;
}

/// Computes the overall wellness flag from score + individual metric statuses.
StatusFlagData computeFlag({
  required int score,
  required String? bpStatus,
  required String? glucoseStatus,
  required int? age,
}) {
  final isUnder30 = age != null && age < 30;
  final isOver60 = age != null && age >= 60;

  if (glucoseStatus == 'CRITICAL' || score < 40) {
    return const StatusFlagData(
      label: 'Urgent', emoji: '🚨', color: AppColors.statusCritical,
    );
  }

  if (bpStatus == 'HIGH - STAGE 2') {
    if (isOver60) {
      return const StatusFlagData(
        label: 'At Risk', subLabel: 'Monitor Blood Pressure',
        emoji: '🟠', color: AppColors.statusElevated,
      );
    }
    return const StatusFlagData(
      label: 'Urgent', subLabel: 'Check Medication',
      emoji: '🚨', color: AppColors.statusHigh,
    );
  }

  if (bpStatus == 'HIGH - STAGE 1' || bpStatus == 'ELEVATED') {
    if (isUnder30) {
      return const StatusFlagData(
        label: 'At Risk', subLabel: 'Monitor Blood Pressure',
        emoji: '🟠', color: AppColors.statusElevated,
      );
    }
    return const StatusFlagData(
      label: 'Caution', subLabel: 'Monitor BP',
      emoji: '🟡', color: AppColors.amber,
    );
  }

  if (glucoseStatus != null && glucoseStatus.contains('HIGH')) {
    return const StatusFlagData(
      label: 'Caution', subLabel: 'Monitor Glucose',
      emoji: '🟡', color: AppColors.amber,
    );
  }

  if (score >= 70) {
    return const StatusFlagData(
      label: 'Fit & Fine', emoji: '🟢', color: AppColors.statusNormal,
    );
  }
  if (score >= 55) {
    return const StatusFlagData(
      label: 'Caution', emoji: '🟡', color: AppColors.amber,
    );
  }
  return const StatusFlagData(
    label: 'At Risk', emoji: '🟠', color: AppColors.statusElevated,
  );
}

/// Format large point numbers compactly (e.g. 1500 → "1.5k").
String fmtPoints(int pts) {
  if (pts >= 1000) return '${(pts / 1000).toStringAsFixed(pts % 1000 == 0 ? 0 : 1)}k';
  return '$pts';
}
