// Context: Main dashboard — glassmorphism redesign matching dashboard1.html.
// Related: lib/widgets/glass_card.dart, lib/theme/app_theme.dart, backend/routes_health.py

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'select_profile_screen.dart';
import 'manage_access_screen.dart';
import 'photo_scan_screen.dart';
import 'reading_confirmation_screen.dart';
import 'trend_chart_screen.dart';
import '../services/storage_service.dart';
import '../services/health_reading_service.dart';
import '../services/profile_service.dart';
import '../models/profile_model.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../main.dart' show routeObserver;
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final HealthReadingService _readingService = HealthReadingService();
  final ProfileService _profileService = ProfileService();

  String _activeProfileName = "Health";
  int? _activeProfileId;
  Future<Map<String, dynamic>>? _healthScoreFuture;
  Future<String>? _aiInsightFuture;
  ProfileModel? _activeProfile;

  // Cached for header pills (updated when health score loads)
  int _streak = 0;
  int _pts = 0;
  bool _insightSaved = false;

  // Pulsing dot animation for AI insight card
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadProfileInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (_activeProfileId != null) _refreshHealthScore(_activeProfileId!);
  }

  Future<void> _loadProfileInfo() async {
    final name = await _storageService.getActiveProfileName();
    final id = await _storageService.getActiveProfileId();
    if (mounted) {
      setState(() {
        if (name != null) _activeProfileName = name;
        _activeProfileId = id;
        if (id != null) _refreshHealthScore(id);
      });
    }
  }

  void _refreshHealthScore(int profileId) async {
    final token = await _storageService.getToken();
    if (token == null || !mounted) return;
    final future = _readingService.getHealthScore(token, profileId);
    setState(() {
      _healthScoreFuture = future;
      _aiInsightFuture = _readingService.getAiInsight(token, profileId);
    });
    // Update header pills when data arrives
    try {
      final data = await future;
      if (mounted) {
        setState(() {
          _streak = (data['streak_days'] as num?)?.toInt() ?? 0;
          _pts = _streakToPoints(_streak);
        });
      }
    } catch (_) {}
    // Fetch profile for physician card (parallel)
    try {
      final profile = await _profileService.getProfile(token, profileId);
      if (mounted) setState(() => _activeProfile = profile);
    } catch (_) {}
  }

  Future<void> _logout(BuildContext ctx) async {
    await _storageService.clearAll();
    if (!ctx.mounted) return;
    Navigator.pushReplacement(
      ctx,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (_activeProfileId != null) _refreshHealthScore(_activeProfileId!);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(l10n),
                const SizedBox(height: 16),

                if (_healthScoreFuture != null)
                  FutureBuilder<Map<String, dynamic>>(
                    future: _healthScoreFuture,
                    builder: (context, snap) {
                      final data = snap.data;
                      final isLoading =
                          snap.connectionState == ConnectionState.waiting;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWellnessCard(data, isLoading, l10n),
                          const SizedBox(height: 16),
                          _buildVitalSummaryCard(data, l10n),
                          const SizedBox(height: 16),
                          if (_aiInsightFuture != null)
                            _buildAiInsightCard(l10n),
                          const SizedBox(height: 16),
                          if (_activeProfile?.doctorName?.isNotEmpty == true)
                            _buildPhysicianCard(l10n),
                          if (_activeProfile?.doctorName?.isNotEmpty == true)
                            const SizedBox(height: 16),
                          _buildMetricsGrid(data, l10n),
                          const SizedBox(height: 16),
                          _buildFooter(l10n),
                        ],
                      );
                    },
                  )
                else
                  _buildNoProfileState(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? l10n.goodMorning
        : hour >= 12 && hour < 17
            ? l10n.goodAfternoon
            : hour >= 17 && hour < 22
                ? l10n.goodEvening
                : l10n.hello;

    // Profile name shown separately — greeting is always accurate
    final hasProfile = _activeProfileId != null;
    final profileDisplayName = _activeProfileName == 'Health'
        ? 'My Profile'
        : _activeProfileName;

    return Column(
      children: [
        // SWASTH label + greeting + avatar
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SWASTH',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (hasProfile)
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SelectProfileScreen()),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            profileDisplayName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.swap_horiz, size: 13, color: AppColors.primary),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Avatar → tap to switch profile
            PopupMenuButton<String>(
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'switch') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SelectProfileScreen()),
                  );
                } else if (val == 'profile' && _activeProfileId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(profileId: _activeProfileId!),
                    ),
                  );
                } else if (val == 'share' && _activeProfileId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManageAccessScreen(
                        profileId: _activeProfileId!,
                        profileName: _activeProfileName,
                      ),
                    ),
                  );
                } else if (val == 'logout') {
                  _logout(context);
                }
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Text(
                  _activeProfileName.isNotEmpty
                      ? _activeProfileName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'profile', child: Row(children: [const Icon(Icons.person_outline, size: 18), const SizedBox(width: 8), Text(l10n.profile)])),
                PopupMenuItem(value: 'share', child: Row(children: [const Icon(Icons.share_outlined, size: 18), const SizedBox(width: 8), Text(l10n.shareProfile)])),
                PopupMenuItem(value: 'switch', child: Row(children: [const Icon(Icons.swap_horiz, size: 18), const SizedBox(width: 8), Text(l10n.switchProfile)])),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'logout', child: Row(children: [const Icon(Icons.logout, size: 18, color: AppColors.danger), const SizedBox(width: 8), Text(l10n.logout, style: const TextStyle(color: AppColors.danger))])),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Pills row: Language | Streak | Points
        GlassCard(
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PillButton(
                icon: '🇮🇳',
                label: 'ENGLISH',
                onTap: () {
                  if (_activeProfileId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(profileId: _activeProfileId!),
                      ),
                    );
                  }
                },
              ),
              Container(width: 1, height: 24, color: AppColors.separator),
              _PillButton(
                icon: '🔥',
                label: _streak > 0 ? '$_streak DAYS' : 'STREAK',
                onTap: () {},
              ),
              Container(width: 1, height: 24, color: AppColors.separator),
              _PillButton(
                icon: '🏆',
                label: _pts > 0 ? '${_fmtPoints(_pts)} PTS' : 'POINTS',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Wellness Score Ring ───────────────────────────────────────────────────

  Widget _buildWellnessCard(
    Map<String, dynamic>? data,
    bool isLoading,
    AppLocalizations l10n,
  ) {
    if (isLoading) {
      return GlassCard(
        borderRadius: 32,
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }

    final score = (data?['score'] as num?)?.toInt() ?? 50;
    final insight = data?['insight'] as String? ?? '';
    final bpStatus = data?['today_bp_status'] as String?;
    final glucoseStatus = data?['today_glucose_status'] as String?;
    final profileAge = (data?['profile_age'] as num?)?.toInt();
    final lastLogged = _formatLastLogged(data?['last_logged'] as String?);

    final arcColor = _scoreArcColor(score);
    final flagData = _computeFlag(
      score: score,
      bpStatus: bpStatus,
      glucoseStatus: glucoseStatus,
      age: profileAge,
    );

    return GestureDetector(
      onTap: _activeProfileId != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrendChartScreen(profileId: _activeProfileId!),
                ),
              )
          : null,
      child: GlassCard(
        borderRadius: 32,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Stack(
          children: [
            Column(
              children: [
                // Section label
                Text(
                  l10n.wellnessScoreSection.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),

                // Score ring
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: _ScoreRingPainter(score: score.toDouble(), arcColor: arcColor),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$score',
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              height: 1,
                            ),
                          ),
                          if (lastLogged.isNotEmpty)
                            Text(
                              lastLogged,
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Insight quote
                if (insight.isNotEmpty)
                  Text(
                    '"$insight"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 12),

                // Progress bar + score label (text reflects actual score state)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: score / 100,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(arcColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      score >= 70
                          ? l10n.optimumRange.toUpperCase()
                          : score >= 40
                              ? 'MONITOR CLOSELY'
                              : 'NEEDS ATTENTION',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: arcColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Info button (top-right) — replaces inline status badge
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showStatusInfoSheet(context, flagData, l10n),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: const Icon(Icons.question_mark_rounded, size: 14, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vital Summary ─────────────────────────────────────────────────────────

  Widget _buildVitalSummaryCard(Map<String, dynamic>? data, AppLocalizations l10n) {
    final avgSys = (data?['avg_systolic_90d'] as num?)?.toDouble();
    final avgDia = (data?['avg_diastolic_90d'] as num?)?.toDouble();
    final prevAvgSys = (data?['prev_avg_systolic_90d'] as num?)?.toDouble();
    final avgGlucose = (data?['avg_glucose_90d'] as num?)?.toDouble();
    final prevAvgGlucose = (data?['prev_avg_glucose_90d'] as num?)?.toDouble();

    // Dynamic day labels — show actual days with data, capped at 90
    final bpDays = (data?['bp_data_days'] as num?)?.toInt() ?? 0;
    final glucoseDays = (data?['glucose_data_days'] as num?)?.toInt() ?? 0;
    final bpAvgLabel = bpDays > 0 ? '$bpDays-day avg' : l10n.ninetyDayAvg;
    final glucoseAvgLabel = glucoseDays > 0 ? '$glucoseDays-day avg' : l10n.ninetyDayAvg;

    final bpLabel = avgSys != null && avgDia != null
        ? '${avgSys.toStringAsFixed(0)}/${avgDia.toStringAsFixed(0)}'
        : '—';
    final glucoseLabel = avgGlucose != null
        ? '${avgGlucose.toStringAsFixed(0)} mg'
        : '—';

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.vitalSummarySection.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _VitalTile(
                  label: 'BP',
                  subLabel: bpAvgLabel,
                  value: bpLabel,
                  trendLabel: _trendLabel(avgSys, prevAvgSys, lowerIsBetter: true),
                  trendColor: _trendColor(avgSys, prevAvgSys, lowerIsBetter: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VitalTile(
                  label: 'SUGAR',
                  subLabel: glucoseAvgLabel,
                  value: glucoseLabel,
                  trendLabel: _trendLabel(avgGlucose, prevAvgGlucose, lowerIsBetter: true),
                  trendColor: _trendColor(avgGlucose, prevAvgGlucose, lowerIsBetter: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VitalTile(
                  label: 'STEPS',
                  subLabel: '—',
                  value: '—',
                  trendLabel: l10n.trendStable,
                  trendColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── AI Health Insight ─────────────────────────────────────────────────────

  Widget _buildAiInsightCard(AppLocalizations l10n) {
    // Non-uniform borders can't use borderRadius — use Stack + Positioned left bar.
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.aiInsightSection.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, _) => Opacity(
                              opacity: _pulseAnimation.value,
                              child: const CircleAvatar(
                                radius: 3,
                                backgroundColor: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Based on your last 7 days of readings',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<String>(
                        future: _aiInsightFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 40,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                            );
                          }
                          final text = snap.data ?? '';
                          return Text(
                            text.isNotEmpty ? '"$text"' : '"Log daily readings for the best health insights."',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => _insightSaved = !_insightSaved),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Icon(
                      _insightSaved ? Icons.star : Icons.star_border,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Left accent bar on top of GlassCard
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 4,
              child: ColoredBox(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Primary Physician ─────────────────────────────────────────────────────

  Widget _buildPhysicianCard(AppLocalizations l10n) {
    final profile = _activeProfile!;
    final hasWhatsApp = profile.doctorWhatsapp?.isNotEmpty == true;

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: Text('👩‍⚕️', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.primaryPhysicianSection.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.doctorName!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (profile.doctorSpecialty?.isNotEmpty == true)
                  Text(
                    profile.doctorSpecialty!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                Text(
                  l10n.physicianConnected,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          if (hasWhatsApp)
            GestureDetector(
              onTap: () => _openWhatsApp(profile.doctorWhatsapp!),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Center(child: Text('💬', style: TextStyle(fontSize: 18))),
              ),
            ),
        ],
      ),
    );
  }

  // ── Individual Metrics 2×2 Grid ───────────────────────────────────────────

  Widget _buildMetricsGrid(Map<String, dynamic>? data, AppLocalizations l10n) {
    final lastBpSys = (data?['last_bp_systolic'] as num?)?.toDouble();
    final lastBpDia = (data?['last_bp_diastolic'] as num?)?.toDouble();
    final lastBpStatus = data?['last_bp_status'] as String?;
    final lastGlucose = (data?['last_glucose_value'] as num?)?.toDouble();
    final lastGlucoseStatus = data?['last_glucose_status'] as String?;

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
                valueColor: _statusTextColor(lastBpStatus),
                onAddTap: () => _showInputModal(context, l10n: l10n, deviceType: 'blood_pressure', btDeviceType: 'Blood Pressure'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                label: l10n.lastSugar,
                value: glucoseValue,
                valueColor: _statusTextColor(lastGlucoseStatus),
                onAddTap: () => _showInputModal(context, l10n: l10n, deviceType: 'glucose', btDeviceType: 'Glucose'),
              ),
            ),
          ],
        ),
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
                onTap: () {
                  if (_activeProfileId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DashboardScreen(
                          device: null,
                          services: [],
                          deviceType: 'Armband',
                          autoConnect: true,
                          profileId: _activeProfileId!,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        l10n.footerDisclaimer,
        style: const TextStyle(
          fontSize: 9,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── No Profile State ──────────────────────────────────────────────────────

  Widget _buildNoProfileState(AppLocalizations l10n) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.health_and_safety_outlined, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            l10n.noReadingsYetScore,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SelectProfileScreen()),
            ),
            child: Text(l10n.switchProfile),
          ),
        ],
      ),
    );
  }

  // ── Modal: log a reading ──────────────────────────────────────────────────

  void _showInputModal(
    BuildContext context, {
    required AppLocalizations l10n,
    required String deviceType,
    required String btDeviceType,
  }) {
    if (_activeProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectProfileFirst)),
      );
      return;
    }

    final localizedLabel = deviceType == 'glucose' ? l10n.glucometer : l10n.bpMeter;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.logReading(localizedLabel),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.howToLog,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: Text(l10n.scanWithCamera),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoScanScreen(
                        deviceType: deviceType,
                        profileId: _activeProfileId!,
                      ),
                    ),
                  );
                  if (mounted && _activeProfileId != null) {
                    _refreshHealthScore(_activeProfileId!);
                  }
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.bluetooth),
                label: Text(l10n.connectViaBluetooth),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DashboardScreen(
                        device: null,
                        services: [],
                        deviceType: btDeviceType,
                        autoConnect: true,
                        profileId: _activeProfileId!,
                      ),
                    ),
                  );
                  if (mounted && _activeProfileId != null) {
                    _refreshHealthScore(_activeProfileId!);
                  }
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: Text(l10n.enterManually),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReadingConfirmationScreen(
                        ocrResult: null,
                        deviceType: deviceType,
                        profileId: _activeProfileId!,
                      ),
                    ),
                  );
                  if (mounted && _activeProfileId != null) {
                    _refreshHealthScore(_activeProfileId!);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _openWhatsApp(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[\s\-()]'), '');
    final digits = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _formatLastLogged(String? isoString) {
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

  static Color _scoreArcColor(int score) {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return AppColors.amber;
    return AppColors.danger;
  }

  static Color _statusTextColor(String? status) {
    if (status == null) return AppColors.textPrimary;
    if (status == 'NORMAL') return AppColors.success;
    if (status == 'ELEVATED' || status == 'HIGH - STAGE 1') return AppColors.amber;
    if (status.contains('HIGH') || status == 'CRITICAL') return AppColors.danger;
    return AppColors.textPrimary;
  }

  static String _trendLabel(double? current, double? previous,
      {bool lowerIsBetter = true}) {
    if (current == null || previous == null || previous == 0) return 'Stable';
    final pct = ((current - previous) / previous * 100).abs();
    if (pct < 2) return 'Stable';
    final increasing = current > previous;
    final arrow = increasing ? '↑' : '↓';
    return '$arrow ${pct.toStringAsFixed(0)}%';
  }

  static Color _trendColor(double? current, double? previous,
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

  static String _fmtPoints(int pts) {
    if (pts >= 1000) return '${(pts / 1000).toStringAsFixed(pts % 1000 == 0 ? 0 : 1)}k';
    return '$pts';
  }
}

// ── Score Ring CustomPainter ─────────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double score; // 0–100
  final Color arcColor;

  const _ScoreRingPainter({required this.score, required this.arcColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;
    const startAngle = -math.pi / 2; // top
    final sweepAngle = 2 * math.pi * (score / 100);

    final bgPaint = Paint()
      ..color = const Color(0xFFE2E8F0) // slate-200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    if (score > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.score != score || old.arcColor != arcColor;
}

// ── _PillButton ───────────────────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _VitalTile ────────────────────────────────────────────────────────────────

class _VitalTile extends StatelessWidget {
  final String label;
  final String subLabel;  // e.g. "3-day avg" or "90-day avg"
  final String value;
  final String trendLabel;
  final Color trendColor;

  const _VitalTile({
    required this.label,
    required this.subLabel,
    required this.value,
    required this.trendLabel,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          Text(
            subLabel,
            style: const TextStyle(
              fontSize: 8,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            trendLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _MetricTile ───────────────────────────────────────────────────────────────

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

// ── _ArmBandTile ──────────────────────────────────────────────────────────────

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

// ── Status flag data + computation ───────────────────────────────────────────

class _StatusFlagData {
  final String label;
  final String? subLabel;
  final Color color;
  final String emoji;

  const _StatusFlagData({
    required this.label,
    this.subLabel,
    required this.color,
    required this.emoji,
  });
}

_StatusFlagData _computeFlag({
  required int score,
  required String? bpStatus,
  required String? glucoseStatus,
  required int? age,
}) {
  final isUnder30 = age != null && age < 30;
  final isOver60 = age != null && age >= 60;

  if (glucoseStatus == 'CRITICAL' || score < 40) {
    return const _StatusFlagData(
      label: 'Urgent', emoji: '🚨', color: AppColors.statusCritical,
    );
  }

  if (bpStatus == 'HIGH - STAGE 2') {
    if (isOver60) {
      return const _StatusFlagData(
        label: 'At Risk', subLabel: 'Monitor Blood Pressure',
        emoji: '🟠', color: AppColors.statusElevated,
      );
    }
    return const _StatusFlagData(
      label: 'Urgent', subLabel: 'Check Medication',
      emoji: '🚨', color: AppColors.statusHigh,
    );
  }

  if (bpStatus == 'HIGH - STAGE 1' || bpStatus == 'ELEVATED') {
    if (isUnder30) {
      return const _StatusFlagData(
        label: 'At Risk', subLabel: 'Monitor Blood Pressure',
        emoji: '🟠', color: AppColors.statusElevated,
      );
    }
    return const _StatusFlagData(
      label: 'Caution', subLabel: 'Monitor BP',
      emoji: '🟡', color: AppColors.amber,
    );
  }

  if (glucoseStatus != null && glucoseStatus.contains('HIGH')) {
    return const _StatusFlagData(
      label: 'Caution', subLabel: 'Monitor Glucose',
      emoji: '🟡', color: AppColors.amber,
    );
  }

  if (score >= 70) {
    return const _StatusFlagData(
      label: 'Fit & Fine', emoji: '🟢', color: AppColors.statusNormal,
    );
  }
  if (score >= 55) {
    return const _StatusFlagData(
      label: 'Caution', emoji: '🟡', color: AppColors.amber,
    );
  }
  return const _StatusFlagData(
    label: 'At Risk', emoji: '🟠', color: AppColors.statusElevated,
  );
}

int _streakToPoints(int streak) {
  if (streak >= 30) return 1500;
  if (streak >= 14) return 700;
  if (streak >= 7) return 300;
  if (streak >= 3) return 100;
  if (streak >= 1) return 10;
  return 0;
}

// ── Status info bottom sheet ──────────────────────────────────────────────────

void _showStatusInfoSheet(
  BuildContext context,
  _StatusFlagData current,
  AppLocalizations l10n,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StatusInfoSheet(current: current),
  );
}

class _StatusInfoSheet extends StatelessWidget {
  final _StatusFlagData current;
  const _StatusInfoSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    const levels = [
      (emoji: '🟢', label: 'Fit & Fine', color: AppColors.statusNormal,
       desc: 'All your readings are within healthy ranges. Keep up the great habits!'),
      (emoji: '🟡', label: 'Caution', color: AppColors.amber,
       desc: 'One or more readings are slightly elevated. Monitor them daily and stay hydrated.'),
      (emoji: '🟠', label: 'At Risk', color: AppColors.statusElevated,
       desc: 'Your readings suggest increased risk. Consider lifestyle changes and consult your doctor.'),
      (emoji: '🚨', label: 'Urgent', color: AppColors.statusCritical,
       desc: 'A critical reading was detected. Please contact your doctor or family member immediately.'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'WELLNESS STATUS',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textSecondary, letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          // Current status highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            decoration: BoxDecoration(
              color: current.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: current.color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Text(current.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your current status',
                      style: TextStyle(fontSize: 11, color: current.color.withValues(alpha: 0.8)),
                    ),
                    Text(
                      current.label,
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: current.color,
                      ),
                    ),
                    if (current.subLabel != null)
                      Text(
                        current.subLabel!,
                        style: TextStyle(fontSize: 12, color: current.color.withValues(alpha: 0.8)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Text(
            'WHAT EACH LEVEL MEANS',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textSecondary, letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ...levels.map((lvl) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lvl.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lvl.label,
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: lvl.color,
                        ),
                      ),
                      Text(
                        lvl.desc,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
