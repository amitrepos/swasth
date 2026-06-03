// 7-day steps line chart (C6 / NUO-22) — Insights tab.
//
// Aggregates step readings already loaded by TrendChartScreen (MAX per
// calendar day — same semantics as GET /readings/steps/daily). Avoids a
// second network round-trip that could hang or race with tab refresh.
// Rendered as a line (with per-day dots) so the daily trend reads at a
// glance, consistent with the glucose/BP/weight/pulse charts.
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

    // Styled to match the Glucose/BP detail cards in TrendChartScreen:
    // uppercase icon header + unit, 200px line chart, stats row underneath.
    return GlassCard(
      key: const Key('insights_steps_chart_card'),
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_walk,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.stepsChartTitle(days).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: !hasData
                ? _EmptyState(message: l10n.stepsChartEmpty)
                : _Chart(bars: aggregate.bars, goal: aggregate.goal),
          ),
          if (hasData) ...[
            const SizedBox(height: 8),
            _StatsRow(l10n: l10n, aggregate: aggregate),
          ],
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

/// Test seam for the UTC day-bucketing (mirrors backend get_daily_steps).
/// Returns steps per day over the [days] window — index 0 = oldest day
/// (startDate), index days-1 = today (UTC); 0 = no reading that UTC day.
/// Needed because axis labels render for every day regardless of data.
@visibleForTesting
List<int> debugDailySteps(List<HealthReading> readings, int days) {
  final agg = _aggregateDailySteps(readings, days);
  return [for (final b in agg.bars) b.steps];
}

class _DayBar {
  final DateTime date;
  final int steps;
  final int? goal;
  _DayBar({required this.date, required this.steps, this.goal});
}

class _StatsRow extends StatelessWidget {
  final AppLocalizations l10n;
  final _DailyStepsAggregate aggregate;

  const _StatsRow({required this.l10n, required this.aggregate});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCell(
          label: l10n.stepsTotalLabel,
          value: fmt.format(aggregate.total),
          color: AppColors.primary,
        ),
        _StatCell(
          label: l10n.avgLabel,
          value: fmt.format(aggregate.avg),
        ),
        if (aggregate.goal != null)
          _StatCell(
            label: l10n.stepsGoalLabel,
            value: '${aggregate.goalHitDays}/${aggregate.bars.length}',
            color: AppColors.scoreHealthy,
          ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatCell({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
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
    final locale = Localizations.localeOf(context).languageCode;
    final fmt = NumberFormat.decimalPattern(locale);
    final peak = bars.map((b) => b.steps).fold(0, (a, b) => a > b ? a : b);
    // Scale to actual step counts so the line stays visible when peak << goal.
    final yMax = (peak * 1.2).ceilToDouble().clamp(50.0, double.infinity);
    final showGoalLine = goal != null && goal! > 0 && goal! <= yMax;

    final spots = <FlSpot>[
      for (var i = 0; i < bars.length; i++)
        FlSpot(i.toDouble(), bars[i].steps.toDouble()),
    ];

    Color dotColorFor(int steps) {
      if (steps == 0) return AppColors.textTertiary.withValues(alpha: 0.5);
      if (goal != null && goal! > 0 && steps >= goal!) {
        return AppColors.scoreHealthy;
      }
      return AppColors.primary;
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (bars.length - 1).toDouble(),
        minY: 0,
        maxY: yMax,
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
              reservedSize: 40,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= bars.length || (value - i).abs() > 0.01) {
                  return const SizedBox.shrink();
                }
                // Localised so Hindi/Tamil/etc. users see weekday + month in
                // their own script (e.g. "सोम / 3 जून"), not English-only.
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('E', locale).format(bars[i].date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      // Date line ("d MMM") to match the Glucose & BP Overview
                      // axis. >=11sp + textSecondary for elderly legibility.
                      Text(
                        DateFormat('d MMM', locale).format(bars[i].date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) { // ignore: unnecessary_underscores
                final i = spot.x.round();
                final steps =
                    (i >= 0 && i < bars.length) ? bars[i].steps : 0;
                return FlDotCirclePainter(
                  radius: 3.5,
                  color: dotColorFor(steps),
                  strokeWidth: 1.5,
                  strokeColor: AppColors.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipMargin: 4,
            getTooltipItems: (touched) => touched.map((s) {
              final b = bars[s.x.round().clamp(0, bars.length - 1)];
              return LineTooltipItem(
                '${DateFormat.MMMd(locale).format(b.date)}\n${fmt.format(b.steps)}',
                const TextStyle(color: AppColors.onPrimary, fontSize: 11),
              );
            }).toList(),
          ),
        ),
      ),
      duration: Duration.zero,
    );
  }
}
