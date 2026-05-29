// 7-day steps bar chart (C6 / NUO-22) — Insights tab.
//
// Reads `/api/readings/steps/daily` and renders a bar chart with goal line.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';

import '../../services/api_exception.dart';
import '../../services/health_reading_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

class StepsChartCard extends StatefulWidget {
  final int profileId;
  final int days;
  /// Increment from parent on pull-to-refresh / tab revisit to reload data.
  final int refreshSignal;

  const StepsChartCard({
    super.key,
    required this.profileId,
    this.days = 7,
    this.refreshSignal = 0,
  });

  @override
  State<StepsChartCard> createState() => StepsChartCardState();
}

class StepsChartCardState extends State<StepsChartCard> {
  final HealthReadingService _service = HealthReadingService();
  bool _loading = true;
  bool _loadFailed = false;
  List<_DayBar> _bars = const [];
  int _total = 0;
  int _avg = 0;
  int? _goal;
  int _goalHitDays = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(StepsChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.days != widget.days ||
        oldWidget.refreshSignal != widget.refreshSignal) {
      _load();
    }
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Not authenticated');
      final data = await _service.getDailySteps(
        token: token,
        profileId: widget.profileId,
        days: widget.days,
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
        _loadFailed = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      key: const Key('insights_steps_chart_card'),
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            l10n: l10n,
            days: widget.days,
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
                : _loadFailed
                    ? Center(
                        child: Text(
                          l10n.stepsChartLoadError,
                          style: const TextStyle(color: AppColors.statusCritical),
                        ),
                      )
                    : _bars.isEmpty
                        ? _EmptyState(message: l10n.stepsChartEmpty)
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
  final AppLocalizations l10n;
  final int days;
  final int total;
  final int avg;
  final int? goal;
  final int hits;
  final bool loading;

  const _Header({
    required this.l10n,
    required this.days,
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
        Text(
          l10n.stepsChartTitle(days),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (!loading)
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
    final maxVal = [
      ...bars.map((b) => b.steps),
      if (goal != null) goal!,
      1,
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
                    : AppColors.textSecondary.withValues(alpha: 0.45),
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
