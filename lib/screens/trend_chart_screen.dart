import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/health_reading_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'chat_screen.dart';
import 'shell_screen.dart';

// ── Semantic chart colors (distinct from UI palette) ──────────────────────────
const _kGlucoseColor = Color(0xFF10B981);   // emerald-500
const _kSysColor     = Color(0xFFF43F5E);   // rose-500  (systolic)
const _kDiaColor     = Color(0xFFFDA4AF);   // rose-300  (diastolic, lighter)
const _kGridColor    = Color(0x1A64748B);   // slate-500 @ 10%

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

  // Trend summary per period
  final Map<int, String> _summaries = {};
  final Map<int, bool> _summaryLoading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadReadings();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final period = [7, 30, 90][_tabController.index];
      _loadSummary(period);
    }
  }

  Future<void> _loadSummary(int period) async {
    if (_summaries.containsKey(period)) return;
    setState(() => _summaryLoading[period] = true);
    try {
      final token = await _storageService.getToken();
      if (token == null) return;
      final summary = await _readingService.getTrendSummary(token, widget.profileId, period);
      if (mounted) setState(() { _summaries[period] = summary; _summaryLoading[period] = false; });
    } catch (_) {
      if (mounted) setState(() => _summaryLoading[period] = false);
    }
  }

  Future<void> _loadReadings() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');
      final readings = await _readingService.getReadings(
        token: token,
        profileId: widget.profileId,
        limit: 200,
      );
      if (mounted) setState(() { _allReadings = readings; _isLoading = false; });
      _loadSummary(7); // Load summary for default tab
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
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: l10n.sevenDays),
            Tab(text: l10n.thirtyDays),
            Tab(text: l10n.ninetyDays),
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
                    _TrendView(readings: _allReadings, days: 7, summary: _summaries[7], summaryLoading: _summaryLoading[7] ?? false, profileId: widget.profileId),
                    _TrendView(readings: _allReadings, days: 30, summary: _summaries[30], summaryLoading: _summaryLoading[30] ?? false, profileId: widget.profileId),
                    _TrendView(readings: _allReadings, days: 90, summary: _summaries[90], summaryLoading: _summaryLoading[90] ?? false, profileId: widget.profileId),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trend view for a given window
// ---------------------------------------------------------------------------

class _TrendView extends StatelessWidget {
  final List<HealthReading> readings;
  final int days;
  final String? summary;
  final bool summaryLoading;
  final int profileId;

  const _TrendView({required this.readings, required this.days, this.summary, this.summaryLoading = false, required this.profileId});

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
            Icon(Icons.show_chart, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(l10n.noChartData, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    // Dot radius scales down for larger windows
    final dotRadius = days <= 30 ? 4.0 : days <= 90 ? 3.0 : 2.0;

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── AI Trend Summary ────────────────────────────────────────
            if (summaryLoading)
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    const Text('Generating summary...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              )
            else if (summary != null && summary!.isNotEmpty)
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$days-Day Summary',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      summary!,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        final msg = 'Based on my $days-day health summary: "${summary!}" — can you give me more details and what I should do?';
                        // Check if we were pushed (from home) BEFORE switching tabs
                        final wasPushed = Navigator.canPop(context);
                        if (wasPushed) {
                          // Pop back to shell first (we're a pushed route from home)
                          Navigator.pop(context);
                        }
                        // Then switch to chat tab with the message
                        ShellScreen.switchToTab(4, chatMessage: msg);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Discuss with AI',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (summary != null && summary!.isNotEmpty || summaryLoading)
              const SizedBox(height: 16),

            // ── Correlation overview (always shown if any data) ──────────
            if (glucose.isNotEmpty || bp.isNotEmpty) ...[
              _CorrelationCard(glucose: glucose, bp: bp, days: days, dotRadius: dotRadius),
              const SizedBox(height: 16),
            ],

            // ── Glucose detail ───────────────────────────────────────────
            if (glucose.isNotEmpty) ...[
              _DetailChartCard(
                icon: Icons.water_drop,
                color: _kGlucoseColor,
                title: l10n.glucoseTrend,
                unit: 'mg/dL',
                child: Column(
                  children: [
                    _GlucoseChart(readings: glucose, days: days, dotRadius: dotRadius),
                    const SizedBox(height: 8),
                    _StatsRow(
                      values: glucose.map((r) => r.glucoseValue!).toList(),
                      statuses: glucose.map((r) => r.statusFlag ?? '').toList(),
                      l10n: l10n,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── BP detail ────────────────────────────────────────────────
            if (bp.isNotEmpty) ...[
              _DetailChartCard(
                icon: Icons.favorite,
                color: _kSysColor,
                title: l10n.bpTrend,
                unit: 'mmHg',
                child: Column(
                  children: [
                    _BpChart(readings: bp, days: days, dotRadius: dotRadius),
                    const SizedBox(height: 8),
                    _BpStatsRow(readings: bp, l10n: l10n),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegendDot(color: _kSysColor, label: 'Systolic'),
                        const SizedBox(width: 20),
                        _LegendDot(color: _kDiaColor, label: 'Diastolic'),
                        const SizedBox(width: 20),
                        _LegendDot(
                          color: AppColors.statusNormal.withValues(alpha: 0.5),
                          label: 'Normal range',
                          isBar: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Correlation card — two stacked mini charts sharing a time axis
// ---------------------------------------------------------------------------

class _CorrelationCard extends StatelessWidget {
  final List<HealthReading> glucose;
  final List<HealthReading> bp;
  final int days;
  final double dotRadius;

  const _CorrelationCard({
    required this.glucose,
    required this.bp,
    required this.days,
    required this.dotRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Insight: days where both were NORMAL
    final glucoseByDay = <String, HealthReading>{};
    for (final r in glucose) {
      glucoseByDay.putIfAbsent(DateFormat('yyyy-MM-dd').format(r.readingTimestamp), () => r);
    }
    final bpByDay = <String, HealthReading>{};
    for (final r in bp) {
      bpByDay.putIfAbsent(DateFormat('yyyy-MM-dd').format(r.readingTimestamp), () => r);
    }
    final sharedDays = glucoseByDay.keys.toSet().intersection(bpByDay.keys.toSet());
    final bothNormal = sharedDays.where((d) =>
        glucoseByDay[d]?.statusFlag == 'NORMAL' && bpByDay[d]?.statusFlag == 'NORMAL').length;
    final total = sharedDays.length;
    final hasBoth = total > 0;
    final pct = hasBoth ? (bothNormal / total * 100).round() : 0;
    final insightColor = pct >= 70 ? AppColors.statusNormal : pct >= 40 ? AppColors.statusElevated : AppColors.statusHigh;
    final insightText = !hasBoth
        ? 'Log both glucose & BP on the same day to see correlation'
        : pct == 100
            ? 'Both glucose & BP were normal on all $total shared day${total > 1 ? 's' : ''} 🎉'
            : 'Both normal on $bothNormal of $total shared day${total > 1 ? 's' : ''} ($pct%)';

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.link, size: 16, color: AppColors.iosPurple),
              const SizedBox(width: 8),
              const Text(
                'GLUCOSE & BP OVERVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Glucose mini chart
          if (glucose.isNotEmpty) ...[
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: _kGlucoseColor)),
                const SizedBox(width: 6),
                const Text('Glucose (mg/dL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kGlucoseColor)),
              ],
            ),
            const SizedBox(height: 6),
            _MiniLineChart(readings: glucose, color: _kGlucoseColor, days: days, dotRadius: dotRadius - 1),
          ],

          if (glucose.isNotEmpty && bp.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.separator, height: 1),
            const SizedBox(height: 12),
          ],

          // BP mini chart
          if (bp.isNotEmpty) ...[
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: _kSysColor)),
                const SizedBox(width: 6),
                const Text('Blood Pressure (mmHg)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kSysColor)),
              ],
            ),
            const SizedBox(height: 6),
            _MiniBpChart(readings: bp, days: days, dotRadius: dotRadius - 1),
          ],

          // Insight badge
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: insightColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: insightColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              insightText,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: insightColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini line chart (130px) — used in correlation card
// ---------------------------------------------------------------------------

class _MiniLineChart extends StatelessWidget {
  final List<HealthReading> readings;
  final Color color;
  final int days;
  final double dotRadius;

  const _MiniLineChart({
    required this.readings,
    required this.color,
    required this.days,
    required this.dotRadius,
  });

  @override
  Widget build(BuildContext context) {
    final windowStart = DateTime.now().subtract(Duration(days: days));
    final spots = <FlSpot>[];
    for (final r in readings) {
      final x = r.readingTimestamp.difference(windowStart).inHours.toDouble();
      spots.add(FlSpot(x, r.glucoseValue!));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    final vals = readings.map((r) => r.glucoseValue!).toList();
    final minY = (vals.reduce((a, b) => a < b ? a : b) - 15).clamp(0.0, double.infinity);
    final maxY = vals.reduce((a, b) => a > b ? a : b) + 15;
    final maxX = (days * 24).toDouble();

    return SizedBox(
      height: 110,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2,
              dotData: FlDotData(
                show: dotRadius >= 2,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: dotRadius,
                  color: color,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minY: minY, maxY: maxY,
          minX: 0, maxX: maxX,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: (maxY - minY) / 2,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: _xInterval(days),
                getTitlesWidget: (v, _) {
                  final dt = DateTime.now().subtract(Duration(days: days)).add(Duration(hours: v.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(_xDateLabel(dt, days), style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: _kGridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final dt = DateTime.now().subtract(Duration(days: days)).add(Duration(hours: s.x.toInt()));
                return LineTooltipItem(
                  '${s.y.toStringAsFixed(0)} mg/dL\n${DateFormat('d MMM').format(dt)}',
                  TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBpChart extends StatelessWidget {
  final List<HealthReading> readings;
  final int days;
  final double dotRadius;

  const _MiniBpChart({required this.readings, required this.days, required this.dotRadius});

  @override
  Widget build(BuildContext context) {
    final windowStart = DateTime.now().subtract(Duration(days: days));
    final sysSpots = <FlSpot>[];
    final diaSpots = <FlSpot>[];
    for (final r in readings) {
      final x = r.readingTimestamp.difference(windowStart).inHours.toDouble();
      sysSpots.add(FlSpot(x, r.systolic!));
      if (r.diastolic != null) diaSpots.add(FlSpot(x, r.diastolic!));
    }
    if (sysSpots.isEmpty) return const SizedBox.shrink();

    final allVals = [...readings.map((r) => r.systolic!), ...readings.where((r) => r.diastolic != null).map((r) => r.diastolic!)];
    final minY = (allVals.reduce((a, b) => a < b ? a : b) - 10).clamp(0.0, double.infinity);
    final maxY = allVals.reduce((a, b) => a > b ? a : b) + 15;
    final maxX = (days * 24).toDouble();

    return SizedBox(
      height: 110,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: sysSpots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _kSysColor,
              barWidth: 2,
              dotData: FlDotData(
                show: dotRadius >= 2,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: dotRadius,
                  color: _kSysColor,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [_kSysColor.withValues(alpha: 0.12), _kSysColor.withValues(alpha: 0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (diaSpots.isNotEmpty)
              LineChartBarData(
                spots: diaSpots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: _kDiaColor,
                barWidth: 1.5,
                dotData: FlDotData(
                  show: dotRadius >= 2,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: dotRadius - 0.5,
                    color: _kDiaColor,
                    strokeWidth: 1,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(show: false),
              ),
          ],
          minY: minY, maxY: maxY,
          minX: 0, maxX: maxX,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: (maxY - minY) / 2,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: _xInterval(days),
                getTitlesWidget: (v, _) {
                  final dt = DateTime.now().subtract(Duration(days: days)).add(Duration(hours: v.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(_xDateLabel(dt, days), style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: _kGridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final dt = DateTime.now().subtract(Duration(days: days)).add(Duration(hours: s.x.toInt()));
                final label = s.barIndex == 0 ? 'Sys' : 'Dia';
                final c = s.barIndex == 0 ? _kSysColor : _kDiaColor;
                return LineTooltipItem(
                  '$label: ${s.y.toStringAsFixed(0)} mmHg\n${DateFormat('d MMM').format(dt)}',
                  TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600),
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
// Detail chart card wrapper
// ---------------------------------------------------------------------------

class _DetailChartCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String unit;
  final Widget child;

  const _DetailChartCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.unit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 6),
              Text('($unit)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-size glucose line chart (200px)
// ---------------------------------------------------------------------------

class _GlucoseChart extends StatelessWidget {
  final List<HealthReading> readings;
  final int days;
  final double dotRadius;

  const _GlucoseChart({required this.readings, required this.days, required this.dotRadius});

  @override
  Widget build(BuildContext context) {
    final windowStart = DateTime.now().subtract(Duration(days: days));
    final spots = <FlSpot>[];
    for (final r in readings) {
      final x = r.readingTimestamp.difference(windowStart).inHours.toDouble();
      spots.add(FlSpot(x, r.glucoseValue!));
    }

    final vals = readings.map((r) => r.glucoseValue!).toList();
    final minY = (vals.reduce((a, b) => a < b ? a : b) - 20).clamp(0.0, double.infinity);
    final maxY = vals.reduce((a, b) => a > b ? a : b) + 30;
    final maxX = (days * 24).toDouble();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(
                y1: 70, y2: 130,
                color: _kGlucoseColor.withValues(alpha: 0.08),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _kGlucoseColor,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) {
                  // find nearest reading by x proximity
                  final r = _nearestReading(spot.x, readings, windowStart);
                  return FlDotCirclePainter(
                    radius: dotRadius,
                    color: _dotColor(r?.statusFlag),
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [_kGlucoseColor.withValues(alpha: 0.12), _kGlucoseColor.withValues(alpha: 0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minY: minY, maxY: maxY,
          minX: 0, maxX: maxX,
          titlesData: _titlesData(days, maxY, minY),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 30,
            getDrawingHorizontalLine: (_) => const FlLine(color: _kGridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final dt = windowStart.add(Duration(hours: s.x.toInt()));
                return LineTooltipItem(
                  '${s.y.toStringAsFixed(0)} mg/dL\n${DateFormat('d MMM').format(dt)}',
                  const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
      case 'NORMAL': return _kGlucoseColor;
      case 'HIGH':
      case 'HIGH - STAGE 1':
      case 'HIGH - STAGE 2': return AppColors.statusElevated;
      case 'CRITICAL': return AppColors.statusCritical;
      case 'LOW': return AppColors.statusLow;
      default: return _kGlucoseColor;
    }
  }
}

// ---------------------------------------------------------------------------
// Full-size BP chart (200px)
// ---------------------------------------------------------------------------

class _BpChart extends StatelessWidget {
  final List<HealthReading> readings;
  final int days;
  final double dotRadius;

  const _BpChart({required this.readings, required this.days, required this.dotRadius});

  @override
  Widget build(BuildContext context) {
    final windowStart = DateTime.now().subtract(Duration(days: days));
    final sysSpots = <FlSpot>[];
    final diaSpots = <FlSpot>[];

    for (final r in readings) {
      final x = r.readingTimestamp.difference(windowStart).inHours.toDouble();
      sysSpots.add(FlSpot(x, r.systolic!));
      if (r.diastolic != null) diaSpots.add(FlSpot(x, r.diastolic!));
    }

    final allVals = [...readings.map((r) => r.systolic!), ...readings.where((r) => r.diastolic != null).map((r) => r.diastolic!)];
    final minY = (allVals.reduce((a, b) => a < b ? a : b) - 15).clamp(0.0, double.infinity);
    final maxY = allVals.reduce((a, b) => a > b ? a : b) + 20;
    final maxX = (days * 24).toDouble();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(y1: 90, y2: 130, color: AppColors.statusNormal.withValues(alpha: 0.08)),
              HorizontalRangeAnnotation(y1: 60, y2: 85, color: AppColors.statusNormal.withValues(alpha: 0.08)),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: sysSpots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _kSysColor,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: dotRadius,
                  color: _kSysColor,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [_kSysColor.withValues(alpha: 0.10), _kSysColor.withValues(alpha: 0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (diaSpots.isNotEmpty)
              LineChartBarData(
                spots: diaSpots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: _kDiaColor,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: dotRadius - 0.5,
                    color: _kDiaColor,
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(show: false),
              ),
          ],
          minY: minY, maxY: maxY,
          minX: 0, maxX: maxX,
          titlesData: _titlesData(days, maxY, minY),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => const FlLine(color: _kGridColor, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                final windowStart2 = DateTime.now().subtract(Duration(days: days));
                return spots.map((s) {
                  final dt = windowStart2.add(Duration(hours: s.x.toInt()));
                  final label = s.barIndex == 0 ? 'Sys' : 'Dia';
                  final c = s.barIndex == 0 ? _kSysColor : _kDiaColor;
                  return LineTooltipItem(
                    '$label: ${s.y.toStringAsFixed(0)} mmHg\n${DateFormat('d MMM').format(dt)}',
                    TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
                  );
                }).toList();
              },
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

/// X-axis tick interval in hours based on window size
double _xInterval(int days) {
  if (days <= 30) return 24 * 7;          // weekly ticks
  if (days <= 90) return 24 * 21;         // tri-weekly ticks
  return 24 * 60;                          // bi-monthly ticks for yearly
}

/// Short date label for X axis
String _xDateLabel(DateTime dt, int days) {
  if (days <= 90) return DateFormat('d MMM').format(dt);
  return DateFormat('MMM').format(dt);     // just month for yearly
}

FlTitlesData _titlesData(int days, double maxY, double minY) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: ((maxY - minY) / 4).roundToDouble().clamp(10, 50),
        getTitlesWidget: (v, _) => Text(
          v.toStringAsFixed(0),
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: _xInterval(days),
        getTitlesWidget: (v, _) {
          final dt = DateTime.now().subtract(Duration(days: days)).add(Duration(hours: v.toInt()));
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _xDateLabel(dt, days),
              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
            ),
          );
        },
      ),
    ),
  );
}

HealthReading? _nearestReading(double x, List<HealthReading> readings, DateTime windowStart) {
  HealthReading? best;
  double bestDiff = double.infinity;
  for (final r in readings) {
    final rx = r.readingTimestamp.difference(windowStart).inHours.toDouble();
    final diff = (rx - x).abs();
    if (diff < bestDiff) { bestDiff = diff; best = r; }
  }
  return best;
}

class _StatsRow extends StatelessWidget {
  final List<double> values;
  final List<String> statuses;
  final AppLocalizations l10n;

  const _StatsRow({required this.values, required this.statuses, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final normalPct = statuses.isNotEmpty
        ? (statuses.where((s) => s == 'NORMAL').length / statuses.length * 100).round()
        : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCell(label: l10n.avgLabel, value: avg.toStringAsFixed(0)),
        _StatCell(label: l10n.minLabel, value: min.toStringAsFixed(0)),
        _StatCell(label: l10n.maxLabel, value: max.toStringAsFixed(0)),
        _StatCell(label: l10n.normalPct, value: '$normalPct%', color: _kGlucoseColor),
      ],
    );
  }
}

class _BpStatsRow extends StatelessWidget {
  final List<HealthReading> readings;
  final AppLocalizations l10n;

  const _BpStatsRow({required this.readings, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();
    final sysVals = readings.map((r) => r.systolic!).toList();
    final diaVals = readings.where((r) => r.diastolic != null).map((r) => r.diastolic!).toList();
    final avgSys = sysVals.reduce((a, b) => a + b) / sysVals.length;
    final avgDia = diaVals.isNotEmpty ? diaVals.reduce((a, b) => a + b) / diaVals.length : 0.0;
    final normalPct = (readings.where((r) => r.statusFlag == 'NORMAL').length / readings.length * 100).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatCell(label: 'Avg Sys', value: avgSys.toStringAsFixed(0), color: _kSysColor),
        _StatCell(label: 'Avg Dia', value: avgDia.toStringAsFixed(0), color: _kDiaColor),
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
            color: color ?? AppColors.textPrimary,
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
            ? Container(width: 16, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))
            : Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
