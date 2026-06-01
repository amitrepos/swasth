// 7-day steps bar chart (C6 / NUO-22) — Insights tab.
//
// Aggregates step readings already loaded by TrendChartScreen (MAX per
// calendar day — same semantics as GET /readings/steps/daily). Avoids a
// second network round-trip that could hang or race with tab refresh.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';

import '../../services/health_reading_service.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

class StepsChartCard extends StatelessWidget {
  final List<HealthReading> readings;
  final int days;

  const StepsChartCard({
    super.key,
    required this.readings,
    this.days = 7,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final aggregate = _aggregateDailySteps(readings, days);
    final hasData = aggregate.bars.any((b) => b.steps > 0);

    return GlassCard(
      key: const Key('insights_steps_chart_card'),
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            l10n: l10n,
            days: days,
            total: aggregate.total,
            avg: aggregate.avg,
            goal: aggregate.goal,
            hits: aggregate.goalHitDays,
            hasData: hasData,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: !hasData
                ? _EmptyState(message: l10n.stepsChartEmpty)
                : _Chart(bars: aggregate.bars, goal: aggregate.goal),
          ),
        ],
      ),
    );
  }
}

class _DailyStepsAggregate {
  final List<_DayBar> bars;
  final int total;
  final int avg;
  final int? goal;
  final int goalHitDays;

  const _DailyStepsAggregate({
    required this.bars,
    required this.total,
    required this.avg,
    required this.goal,
    required this.goalHitDays,
  });
}

/// MAX-per-UTC-day aggregation — mirrors backend/routes_health.py#get_daily_steps.
_DailyStepsAggregate _aggregateDailySteps(List<HealthReading> readings, int days) {
  final now = DateTime.now().toUtc();
  final today = DateTime.utc(now.year, now.month, now.day);
  final startDate = today.subtract(Duration(days: days - 1));

  final byDay = <DateTime, int>{};
  int? latestGoal;

  for (final r in readings) {
    if (r.readingType != 'steps' || r.stepsCount == null) continue;
    final ts = r.readingTimestamp.toUtc();
    final d = DateTime.utc(ts.year, ts.month, ts.day);
    if (d.isBefore(startDate) || d.isAfter(today)) continue;

    var steps = r.stepsCount!;
    if (r.valueNumeric > steps) {
      steps = r.valueNumeric.round();
    }
    final prev = byDay[d] ?? 0;
    if (steps > prev) byDay[d] = steps;
    if (r.stepsGoal != null) latestGoal = r.stepsGoal;
  }

  final bars = <_DayBar>[];
  var total = 0;
  var goalHitDays = 0;
  for (var i = 0; i < days; i++) {
    final d = startDate.add(Duration(days: i));
    final stepsVal = byDay[d] ?? 0;
    total += stepsVal;
    if (latestGoal != null && stepsVal >= latestGoal) {
      goalHitDays++;
    }
    bars.add(_DayBar(date: d, steps: stepsVal, goal: latestGoal));
  }

  return _DailyStepsAggregate(
    bars: bars,
    total: total,
    avg: days > 0 ? (total / days).round() : 0,
    goal: latestGoal,
    goalHitDays: goalHitDays,
  );
}

class _DayBar {
  final DateTime date;
  final int steps;
  final int? goal;
  _DayBar({required this.date, required this.steps, this.goal});
}

class _Header extends StatelessWidget {
  final AppLocalizations l10n;
  final int days;
  final int total;
  final int avg;
  final int? goal;
  final int hits;
  final bool hasData;

  const _Header({
    required this.l10n,
    required this.days,
    required this.total,
    required this.avg,
    required this.goal,
    required this.hits,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.directions_walk, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          l10n.stepsChartTitle(days),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (hasData)
          Text(
            goal != null
                ? l10n.stepsChartSummaryWithGoal(
                    fmt.format(total),
                    fmt.format(avg),
                    hits,
                    days,
                  )
                : l10n.stepsChartSummary(fmt.format(total), fmt.format(avg)),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      );
}

class _Chart extends StatelessWidget {
  final List<_DayBar> bars;
  final int? goal;
  const _Chart({required this.bars, required this.goal});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final peak = bars.map((b) => b.steps).fold(0, (a, b) => a > b ? a : b);
    // Scale to actual step counts so bars stay visible when peak << goal.
    final yMax = (peak * 1.2).ceilToDouble().clamp(50.0, double.infinity);
    final showGoalLine =
        goal != null && goal! > 0 && goal! <= yMax;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: yMax,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 3,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.separator,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= bars.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    DateFormat('E').format(bars[i].date),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: showGoalLine
            ? ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: goal!.toDouble(),
                    color: AppColors.amber,
                    strokeWidth: 1.5,
                    dashArray: [4, 4],
                  ),
                ],
              )
            : const ExtraLinesData(),
        barGroups: [
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bars[i].steps.toDouble(),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  color: bars[i].steps == 0
                      ? AppColors.textTertiary.withValues(alpha: 0.35)
                      : (goal != null &&
                              goal! > 0 &&
                              bars[i].steps >= goal!)
                          ? AppColors.scoreHealthy
                          : AppColors.primary,
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipMargin: 4,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final b = bars[group.x];
              return BarTooltipItem(
                '${DateFormat.MMMd().format(b.date)}\n${fmt.format(b.steps)}',
                const TextStyle(color: AppColors.onPrimary, fontSize: 11),
              );
            },
          ),
        ),
      ),
      duration: Duration.zero,
    );
  }
}
