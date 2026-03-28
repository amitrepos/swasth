import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/health_reading_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class TrendChartScreen extends StatefulWidget {
  final int profileId;

  const TrendChartScreen({super.key, required this.profileId});

  @override
  State<TrendChartScreen> createState() => _TrendChartScreenState();
}

class _TrendChartScreenState extends State<TrendChartScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HealthReadingService _readingService = HealthReadingService();
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  List<HealthReading> _allReadings = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReadings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReadings() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');
      final readings = await _readingService.getReadings(
        token: token,
        profileId: widget.profileId,
        limit: 60,
      );
      if (mounted) setState(() { _allReadings = readings; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.healthTrends),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.sevenDays),
            Tab(text: l10n.thirtyDays),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.statusCritical)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _TrendView(readings: _allReadings, days: 7),
                    _TrendView(readings: _allReadings, days: 30),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trend view for a given time window
// ---------------------------------------------------------------------------

class _TrendView extends StatelessWidget {
  final List<HealthReading> readings;
  final int days;

  const _TrendView({required this.readings, required this.days});

  List<HealthReading> get _filtered {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return readings.where((r) => r.readingTimestamp.isAfter(cutoff)).toList()
      ..sort((a, b) => a.readingTimestamp.compareTo(b.readingTimestamp));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filtered;
    final glucose = filtered.where((r) => r.readingType == 'glucose' && r.glucoseValue != null).toList();
    final bp = filtered.where((r) => r.readingType == 'blood_pressure' && r.systolic != null).toList();

    if (glucose.isEmpty && bp.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(l10n.noChartData, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    // Build day-keyed maps for correlation
    final glucoseByDay = <String, HealthReading>{};
    for (final r in glucose) {
      final key = DateFormat('yyyy-MM-dd').format(r.readingTimestamp);
      glucoseByDay.putIfAbsent(key, () => r);
    }
    final bpByDay = <String, HealthReading>{};
    for (final r in bp) {
      final key = DateFormat('yyyy-MM-dd').format(r.readingTimestamp);
      bpByDay.putIfAbsent(key, () => r);
    }
    final sharedDays = glucoseByDay.keys.toSet().intersection(bpByDay.keys.toSet()).toList()..sort();

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Correlation chart (top) ──────────────────────────────────
            if (sharedDays.isNotEmpty) ...[
              _CorrelationChart(
                sharedDays: sharedDays,
                glucoseByDay: glucoseByDay,
                bpByDay: bpByDay,
                days: days,
              ),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 20),
            ],

            // ── Glucose trend ────────────────────────────────────────────
            if (glucose.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.water_drop,
                color: AppColors.glucose,
                title: l10n.glucoseTrend,
                unit: 'mg/dL',
              ),
              const SizedBox(height: 8),
              _GlucoseChart(readings: glucose),
              const SizedBox(height: 8),
              _StatsRow(
                values: glucose.map((r) => r.glucoseValue!).toList(),
                statuses: glucose.map((r) => r.statusFlag ?? '').toList(),
              ),
            ],
            if (glucose.isNotEmpty && bp.isNotEmpty) const SizedBox(height: 32),

            // ── BP trend ─────────────────────────────────────────────────
            if (bp.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.favorite,
                color: AppColors.bloodPressure,
                title: l10n.bpTrend,
                unit: 'mmHg',
              ),
              const SizedBox(height: 8),
              _BpChart(readings: bp),
              const SizedBox(height: 8),
              _BpStatsRow(readings: bp),
            ],
            const SizedBox(height: 24),
            // Legend
            if (bp.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: AppColors.bloodPressure, label: 'Systolic'),
                  const SizedBox(width: 24),
                  _LegendDot(color: AppColors.bloodPressure.withOpacity(0.5), label: 'Diastolic'),
                  const SizedBox(width: 24),
                  _LegendDot(color: AppColors.statusNormal.withOpacity(0.5), label: 'Normal range', isBar: true),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Correlation chart — glucose (blue) + systolic BP (red) on same Y axis
// ---------------------------------------------------------------------------

class _CorrelationChart extends StatelessWidget {
  final List<String> sharedDays;         // sorted "yyyy-MM-dd" keys
  final Map<String, HealthReading> glucoseByDay;
  final Map<String, HealthReading> bpByDay;
  final int days;

  const _CorrelationChart({
    required this.sharedDays,
    required this.glucoseByDay,
    required this.bpByDay,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final glucoseSpots = <FlSpot>[];
    final sysSpots = <FlSpot>[];

    for (var i = 0; i < sharedDays.length; i++) {
      final day = sharedDays[i];
      glucoseSpots.add(FlSpot(i.toDouble(), glucoseByDay[day]!.glucoseValue!));
      sysSpots.add(FlSpot(i.toDouble(), bpByDay[day]!.systolic!));
    }

    // Insight: count days both were NORMAL
    final bothNormal = sharedDays.where((day) =>
        glucoseByDay[day]?.statusFlag == 'NORMAL' &&
        bpByDay[day]?.statusFlag == 'NORMAL').length;
    final total = sharedDays.length;
    final pct = (bothNormal / total * 100).round();
    final insightColor = pct >= 70 ? AppColors.statusNormal : pct >= 40 ? AppColors.statusElevated : AppColors.statusHigh;
    final insightText = pct == 100
        ? 'Both glucose & BP were normal on all $total day${total > 1 ? 's' : ''} 🎉'
        : 'Both normal on $bothNormal of $total day${total > 1 ? 's' : ''} ($pct%)';

    final allVals = [...glucoseSpots.map((s) => s.y), ...sysSpots.map((s) => s.y)];
    final minY = (allVals.reduce((a, b) => a < b ? a : b) - 20).clamp(0.0, double.infinity);
    final maxY = allVals.reduce((a, b) => a > b ? a : b) + 25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.link, size: 18, color: AppColors.iosPurple),
            const SizedBox(width: 8),
            Text(
              'Glucose × BP Correlation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Text('(last $days days)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Days where both were logged: $total',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        // Chart
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                // Glucose — orange (Apple Health glucose color)
                LineChartBarData(
                  spots: glucoseSpots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.glucose,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.glucose,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(show: false),
                ),
                // Systolic BP — red (Apple Health BP color)
                LineChartBarData(
                  spots: sysSpots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.bloodPressure,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.bloodPressure,
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
              minY: minY,
              maxY: maxY,
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= sharedDays.length) {
                        return const SizedBox.shrink();
                      }
                      final n = sharedDays.length;
                      final targets = <int>{0, n ~/ 3, (2 * n) ~/ 3, n - 1};
                      if (!targets.contains(idx)) return const SizedBox.shrink();
                      final dt = DateTime.parse(sharedDays[idx]);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('d MMM').format(dt),
                          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.textSecondary.withOpacity(0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = s.x.toInt();
                    final isGlucose = s.barIndex == 0;
                    final label = isGlucose ? 'Glucose' : 'Systolic';
                    final unit = isGlucose ? 'mg/dL' : 'mmHg';
                    final dt = idx < sharedDays.length
                        ? DateTime.parse(sharedDays[idx])
                        : DateTime.now();
                    return LineTooltipItem(
                      '$label: ${s.y.toStringAsFixed(0)} $unit\n${DateFormat('d MMM').format(dt)}',
                      TextStyle(
                        color: isGlucose ? AppColors.glucose : AppColors.bloodPressure,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Legend row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _LegendDot(color: AppColors.glucose, label: 'Glucose (mg/dL)'),
            SizedBox(width: 20),
            _LegendDot(color: AppColors.bloodPressure, label: 'Systolic BP (mmHg)'),
          ],
        ),
        const SizedBox(height: 10),

        // Insight badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: insightColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: insightColor.withOpacity(0.25)),
          ),
          child: Text(
            insightText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: insightColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Glucose line chart
// ---------------------------------------------------------------------------

class _GlucoseChart extends StatelessWidget {
  final List<HealthReading> readings;

  const _GlucoseChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < readings.length; i++) {
      spots.add(FlSpot(i.toDouble(), readings[i].glucoseValue!));
    }

    final values = readings.map((r) => r.glucoseValue!).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 20).clamp(0.0, double.infinity);
    final maxY = values.reduce((a, b) => a > b ? a : b) + 30;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(
                y1: 70, y2: 130,
                color: AppColors.statusNormal.withOpacity(0.12),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.glucose,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: _dotColor(readings[spot.x.toInt()].statusFlag),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.glucose.withOpacity(0.06),
              ),
            ),
          ],
          minY: minY,
          maxY: maxY,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (v, _) => _xLabel(v.toInt(), readings),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 30,
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppColors.textSecondary.withOpacity(0.15),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final r = readings[s.x.toInt()];
                return LineTooltipItem(
                  '${s.y.toStringAsFixed(0)} mg/dL\n${DateFormat('MMM d').format(r.readingTimestamp)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Color _dotColor(String? status) {
    switch (status) {
      case 'NORMAL': return AppColors.statusNormal;
      case 'HIGH':
      case 'HIGH - STAGE 1':
      case 'HIGH - STAGE 2': return AppColors.statusElevated;
      case 'CRITICAL': return AppColors.statusCritical;
      case 'LOW': return AppColors.statusLow;
      default: return AppColors.glucose;
    }
  }
}

// ---------------------------------------------------------------------------
// Blood pressure line chart (systolic + diastolic)
// ---------------------------------------------------------------------------

class _BpChart extends StatelessWidget {
  final List<HealthReading> readings;

  const _BpChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final sysSpots = <FlSpot>[];
    final diaSpots = <FlSpot>[];

    for (var i = 0; i < readings.length; i++) {
      final r = readings[i];
      sysSpots.add(FlSpot(i.toDouble(), r.systolic!));
      if (r.diastolic != null) diaSpots.add(FlSpot(i.toDouble(), r.diastolic!));
    }

    final allVals = [...readings.map((r) => r.systolic!), ...readings.where((r) => r.diastolic != null).map((r) => r.diastolic!)];
    final minY = (allVals.reduce((a, b) => a < b ? a : b) - 15).clamp(0.0, double.infinity);
    final maxY = allVals.reduce((a, b) => a > b ? a : b) + 20;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(y1: 90, y2: 130, color: AppColors.statusNormal.withOpacity(0.10)),
              HorizontalRangeAnnotation(y1: 60, y2: 85, color: AppColors.statusNormal.withOpacity(0.10)),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: sysSpots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.bloodPressure,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.bloodPressure,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
            if (diaSpots.isNotEmpty)
              LineChartBarData(
                spots: diaSpots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.bloodPressure.withOpacity(0.5),
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.bloodPressure.withOpacity(0.5),
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(show: false),
              ),
          ],
          minY: minY,
          maxY: maxY,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (v, _) => _xLabel(v.toInt(), readings),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (v) => FlLine(
              color: AppColors.textSecondary.withOpacity(0.15),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final r = readings[s.x.toInt()];
                final label = s.barIndex == 0 ? 'Sys' : 'Dia';
                return LineTooltipItem(
                  '$label: ${s.y.toStringAsFixed(0)}\n${DateFormat('MMM d').format(r.readingTimestamp)}',
                  TextStyle(color: s.barIndex == 0 ? AppColors.bloodPressure : AppColors.bloodPressure.withOpacity(0.5), fontSize: 12),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Widget _xLabel(int index, List<HealthReading> readings) {
  if (index < 0 || index >= readings.length || readings.isEmpty) {
    return const SizedBox.shrink();
  }
  final n = readings.length;
  // Show at most 4 labels: first, ~1/3, ~2/3, last
  final targets = <int>{0, n ~/ 3, (2 * n) ~/ 3, n - 1};
  if (!targets.contains(index)) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      DateFormat('d MMM').format(readings[index].readingTimestamp),
      style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String unit;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text('($unit)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<double> values;
  final List<String> statuses;

  const _StatsRow({required this.values, required this.statuses});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (values.isEmpty) return const SizedBox.shrink();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final normalCount = statuses.where((s) => s == 'NORMAL').length;
    final normalPct = (normalCount / statuses.length * 100).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCell(label: l10n.avgLabel, value: avg.toStringAsFixed(0)),
        _StatCell(label: l10n.minLabel, value: min.toStringAsFixed(0)),
        _StatCell(label: l10n.maxLabel, value: max.toStringAsFixed(0)),
        _StatCell(label: l10n.normalPct, value: '$normalPct%', color: AppColors.statusNormal),
      ],
    );
  }
}

class _BpStatsRow extends StatelessWidget {
  final List<HealthReading> readings;

  const _BpStatsRow({required this.readings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (readings.isEmpty) return const SizedBox.shrink();
    final sysVals = readings.map((r) => r.systolic!).toList();
    final diaVals = readings.where((r) => r.diastolic != null).map((r) => r.diastolic!).toList();

    final avgSys = sysVals.reduce((a, b) => a + b) / sysVals.length;
    final avgDia = diaVals.isNotEmpty ? diaVals.reduce((a, b) => a + b) / diaVals.length : 0.0;
    final normalCount = readings.where((r) => r.statusFlag == 'NORMAL').length;
    final normalPct = (normalCount / readings.length * 100).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCell(label: 'Avg Sys', value: avgSys.toStringAsFixed(0)),
        _StatCell(label: 'Avg Dia', value: avgDia.toStringAsFixed(0)),
        _StatCell(label: l10n.normalPct, value: '$normalPct%', color: AppColors.statusNormal),
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
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool isBar;

  const _LegendDot({required this.color, required this.label, this.isBar = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isBar
            ? Container(width: 16, height: 8, color: color)
            : Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
