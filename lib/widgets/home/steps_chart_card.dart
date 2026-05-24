// 7-day steps bar chart (NUO-22).
//
// Reads the new `/api/readings/steps/daily` endpoint and renders a small
// BarChart on the dashboard. Bars on/above goal are emerald; below-goal
// are slate. Tappable for a 30-day modal could come later.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_exception.dart';
import '../../services/health_reading_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

class StepsChartCard extends StatefulWidget {
  final int profileId;
  const StepsChartCard({super.key, required this.profileId});

  @override
  State<StepsChartCard> createState() => _StepsChartCardState();
}

class _StepsChartCardState extends State<StepsChartCard> {
  final HealthReadingService _service = HealthReadingService();
  bool _loading = true;
  List<_DayBar> _bars = const [];
  int _total = 0;
  int _avg = 0;
  int? _goal;
  int _goalHitDays = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StepsChartCard old) {
    super.didUpdateWidget(old);
    if (old.profileId != widget.profileId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Not authenticated');
      final data = await _service.getDailySteps(
        token: token,
        profileId: widget.profileId,
        days: 7,
      );
      final list = (data['days'] as List? ?? []);
      final bars = <_DayBar>[];
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        bars.add(_DayBar(
          date: DateTime.parse(m['date'] as String),
          steps: (m['steps'] as num?)?.toInt() ?? 0,
          goal: (m['goal'] as num?)?.toInt(),
        ));
      }
      if (!mounted) return;
      setState(() {
        _bars = bars;
        _total = (data['total'] as num?)?.toInt() ?? 0;
        _avg = (data['avg'] as num?)?.toInt() ?? 0;
        _goal = (data['goal'] as num?)?.toInt();
        _goalHitDays = (data['goal_hit_days'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load steps';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load steps';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      key: const Key('steps_chart_card'),
      borderRadius: 16,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            total: _total,
            avg: _avg,
            goal: _goal,
            hits: _goalHitDays,
            loading: _loading,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                    : _bars.isEmpty
                        ? const _EmptyState()
                        : _Chart(bars: _bars, goal: _goal),
          ),
        ],
      ),
    );
  }
}

class _DayBar {
  final DateTime date;
  final int steps;
  final int? goal;
  _DayBar({required this.date, required this.steps, this.goal});
}

class _Header extends StatelessWidget {
  final int total;
  final int avg;
  final int? goal;
  final int hits;
  final bool loading;
  const _Header({
    required this.total,
    required this.avg,
    required this.goal,
    required this.hits,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.directions_walk, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        const Text(
          'Steps · 7 days',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (!loading)
          Text(
            goal != null
                ? '${fmt.format(total)} · avg ${fmt.format(avg)} · ${hits}/7 ≥ goal'
                : '${fmt.format(total)} · avg ${fmt.format(avg)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'No step data yet. Walk a bit and check back tomorrow.',
          style: TextStyle(color: Colors.grey.shade600),
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
    final maxVal = [
      ...bars.map((b) => b.steps),
      if (goal != null) goal!,
      1, // avoid divide-by-zero / collapsed bars on first day
    ].reduce((a, b) => a > b ? a : b);
    final yMax = (maxVal * 1.15).ceilToDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: yMax,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('E').format(bars[i].date),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: goal != null
            ? ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: goal!.toDouble(),
                  color: AppColors.amber,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ])
            : null,
        barGroups: [
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: bars[i].steps.toDouble(),
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                color: (goal != null && bars[i].steps >= goal!)
                    ? AppColors.scoreHealthy
                    : Colors.grey.shade400,
              ),
            ]),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipMargin: 4,
            getTooltipItem: (group, _, rod, __) {
              final b = bars[group.x];
              return BarTooltipItem(
                '${DateFormat.MMMd().format(b.date)}\n${fmt.format(b.steps)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );
  }
}
