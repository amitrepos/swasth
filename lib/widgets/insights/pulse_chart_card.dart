// 7-day heart-rate (pulse) line chart — Insights tab.
//
// Aggregates pulse readings (captured alongside blood-pressure entries)
// already loaded by TrendChartScreen into one AVERAGE-per-calendar-day
// point. Rendered as a curved line with weekday labels and an Avg/Min/Max
// stats row — visually identical to StepsChartCard so the two 7-day cards
// read consistently.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';

import '../../services/health_reading_service.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

// Heart-rate / pulse accent — matches _kPulseColor in TrendChartScreen.
const _kPulseColor = Color(0xFFDC2626); // red-600

class PulseChartCard extends StatelessWidget {
  final List<HealthReading> readings;
  final int days;

  const PulseChartCard({
    super.key,
    required this.readings,
    this.days = 7,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final aggregate = _aggregateDailyPulse(readings, days);
    final hasData = aggregate.points.isNotEmpty;

    return GlassCard(
      key: const Key('insights_pulse_chart_card'),
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                size: 16,
                color: _kPulseColor,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.pulseChartTitle(days).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kPulseColor,
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
                ? _EmptyState(message: l10n.noReadingsInWindowPulse(days))
                : _Chart(aggregate: aggregate),
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

class _PulsePoint {
  final int dayIndex;
  final DateTime date;
  final double avg;
  const _PulsePoint({
    required this.dayIndex,
    required this.date,
    required this.avg,
  });
}

class _PulseAggregate {
  final List<_PulsePoint> points;
  final DateTime startDate;
  final int days;
  final double avg;
  final double min;
  final double max;

  const _PulseAggregate({
    required this.points,
    required this.startDate,
    required this.days,
    required this.avg,
    required this.min,
    required this.max,
  });
}

/// AVERAGE-per-UTC-day aggregation over the [days] window. Uses the same UTC
/// day-boundary as StepsChartCard (which mirrors backend get_daily_steps) so
/// both Insights cards bucket the same reading onto the same x-axis date — a
/// local basis would drift one day vs steps near IST midnight (18:30 UTC).
/// (App-wide move to local-day buckets is a separate backend+dashboard change.)
/// Days without a pulse reading produce no point (a 0 bpm point would be
/// clinically wrong), so the line simply spans the gap between recorded days.
_PulseAggregate _aggregateDailyPulse(List<HealthReading> readings, int days) {
  final now = DateTime.now().toUtc();
  final today = DateTime.utc(now.year, now.month, now.day);
  final startDate = today.subtract(Duration(days: days - 1));

  final byDay = <int, List<double>>{};
  final all = <double>[];

  for (final r in readings) {
    if (r.readingType != 'blood_pressure' || r.pulseRate == null) continue;
    final ts = r.readingTimestamp.toUtc();
    final d = DateTime.utc(ts.year, ts.month, ts.day);
    final idx = d.difference(startDate).inDays;
    if (idx < 0 || idx >= days) continue;
    byDay.putIfAbsent(idx, () => []).add(r.pulseRate!);
    all.add(r.pulseRate!);
  }

  final points = <_PulsePoint>[];
  for (var i = 0; i < days; i++) {
    final vals = byDay[i];
    if (vals == null || vals.isEmpty) continue;
    final dayAvg = vals.reduce((a, b) => a + b) / vals.length;
    points.add(_PulsePoint(
      dayIndex: i,
      date: startDate.add(Duration(days: i)),
      avg: dayAvg,
    ));
  }

  return _PulseAggregate(
    points: points,
    startDate: startDate,
    days: days,
    avg: all.isEmpty ? 0 : all.reduce((a, b) => a + b) / all.length,
    min: all.isEmpty ? 0 : all.reduce((a, b) => a < b ? a : b),
    max: all.isEmpty ? 0 : all.reduce((a, b) => a > b ? a : b),
  );
}

/// Test seam for the UTC day-bucketing (the health-critical path: which date a
/// reading lands on). Returns per-day average bpm over the [days] window —
/// index 0 = oldest day (startDate), index days-1 = today (UTC); null = no
/// reading that UTC day. Needed because axis labels render for every day
/// regardless of data, so widget-tree assertions can't verify bucketing.
@visibleForTesting
List<double?> debugDailyPulseAverages(List<HealthReading> readings, int days) {
  final agg = _aggregateDailyPulse(readings, days);
  final out = List<double?>.filled(days, null);
  for (final p in agg.points) {
    if (p.dayIndex >= 0 && p.dayIndex < days) out[p.dayIndex] = p.avg;
  }
  return out;
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
  final _PulseAggregate aggregate;
  const _Chart({required this.aggregate});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final points = aggregate.points;
    final dataMin = points.map((p) => p.avg).reduce((a, b) => a < b ? a : b);
    final dataMax = points.map((p) => p.avg).reduce((a, b) => a > b ? a : b);
    // Keep the 60–100 bpm resting band visible even when readings cluster.
    final minY = ((dataMin - 10).clamp(0.0, double.infinity)) < 55
        ? (dataMin - 10).clamp(0.0, double.infinity)
        : 55.0;
    final maxY = (dataMax + 10) > 105 ? dataMax + 10 : 105.0;

    final spots = [
      for (final p in points) FlSpot(p.dayIndex.toDouble(), p.avg),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (aggregate.days - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        // Resting heart-rate normal band (60–100 bpm).
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            HorizontalRangeAnnotation(
              y1: 60,
              y2: 100,
              color: AppColors.statusNormal.withValues(alpha: 0.07),
            ),
          ],
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 3,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.separator,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 ||
                    i >= aggregate.days ||
                    (value - i).abs() > 0.01) {
                  return const SizedBox.shrink();
                }
                final d = aggregate.startDate.add(Duration(days: i));
                // Localised so Hindi/Tamil/etc. users see weekday + month in
                // their own script (e.g. "सोम / 3 जून"), not English-only.
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('E', locale).format(d),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      // Date line ("d MMM") to match the Steps / Glucose & BP
                      // axis. >=11sp + textSecondary for elderly legibility.
                      Text(
                        DateFormat('d MMM', locale).format(d),
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
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _kPulseColor,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter( // ignore: unnecessary_underscores
                radius: 3.5,
                color: _kPulseColor,
                strokeWidth: 1.5,
                strokeColor: AppColors.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _kPulseColor.withValues(alpha: 0.15),
                  _kPulseColor.withValues(alpha: 0.0),
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
              final d = aggregate.startDate.add(Duration(days: s.x.round()));
              return LineTooltipItem(
                '${DateFormat.MMMd(locale).format(d)}\n${s.y.toStringAsFixed(0)} bpm',
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

class _StatsRow extends StatelessWidget {
  final AppLocalizations l10n;
  final _PulseAggregate aggregate;

  const _StatsRow({required this.l10n, required this.aggregate});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCell(
          label: l10n.avgLabel,
          value: aggregate.avg.toStringAsFixed(0),
          color: _kPulseColor,
        ),
        _StatCell(label: l10n.minLabel, value: aggregate.min.toStringAsFixed(0)),
        _StatCell(label: l10n.maxLabel, value: aggregate.max.toStringAsFixed(0)),
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
