// Context: Main dashboard — glassmorphism redesign matching dashboard1.html.
// Related: lib/widgets/glass_card.dart, lib/theme/app_theme.dart, backend/routes_health.py

import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'select_profile_screen.dart';
import 'manage_access_screen.dart';
import 'trend_chart_screen.dart';
import '../services/storage_service.dart';
import '../services/health_reading_service.dart';
import '../services/profile_service.dart';
import '../services/sync_service.dart';
import '../models/profile_model.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/health_score_ring.dart';
import '../widgets/home/ai_insight_card.dart';
import '../widgets/home/physician_card.dart';
import '../widgets/home/vital_summary_card.dart';
import '../widgets/home/metrics_grid.dart';
import '../widgets/home/reading_input_modal.dart';
import '../utils/health_helpers.dart' as helpers;
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
  String _accessLevel = "owner";
  Future<Map<String, dynamic>>? _healthScoreFuture;
  Future<String>? _aiInsightFuture;
  ProfileModel? _activeProfile;

  int _streak = 0;
  int _pts = 0;
  bool _insightSaved = false;

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
    SyncService().syncPendingReadings();
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
    final level = await _storageService.getActiveProfileAccessLevel();
    if (mounted) {
      setState(() {
        if (name != null) _activeProfileName = name;
        _activeProfileId = id;
        _accessLevel = level ?? 'owner';
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
    try {
      final data = await future;
      await _storageService.saveHealthScore(profileId, data);
      if (mounted) {
        setState(() {
          _streak = (data['streak_days'] as num?)?.toInt() ?? 0;
          _pts = helpers.streakToPoints(_streak);
        });
      }
    } catch (_) {
      final cached = await _storageService.getCachedHealthScore(profileId);
      if (cached != null && mounted) {
        setState(() {
          _healthScoreFuture = Future.value(cached);
          _streak = (cached['streak_days'] as num?)?.toInt() ?? 0;
          _pts = helpers.streakToPoints(_streak);
        });
      }
    }
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

  Future<void> _openWhatsApp(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[\s\-()]'), '');
    final digits = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleAddReading({required String deviceType, required String btDeviceType}) {
    if (_activeProfileId == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectProfileFirst)),
      );
      return;
    }
    showReadingInputModal(
      context,
      profileId: _activeProfileId!,
      deviceType: deviceType,
      btDeviceType: btDeviceType,
      onReadingSaved: () {
        if (mounted && _activeProfileId != null) {
          _refreshHealthScore(_activeProfileId!);
        }
      },
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
                HomeHeader(
                  activeProfileName: _activeProfileName,
                  activeProfileId: _activeProfileId,
                  streak: _streak,
                  pts: _pts,
                  onSwitchProfile: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SelectProfileScreen()),
                  ),
                  onViewProfile: () {
                    if (_activeProfileId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(profileId: _activeProfileId!),
                        ),
                      );
                    }
                  },
                  onShareProfile: () {
                    if (_activeProfileId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManageAccessScreen(
                            profileId: _activeProfileId!,
                            profileName: _activeProfileName,
                          ),
                        ),
                      );
                    }
                  },
                  onLanguageTap: () {
                    if (_activeProfileId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(profileId: _activeProfileId!),
                        ),
                      );
                    }
                  },
                  onLogout: () => _logout(context),
                ),
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
                          HealthScoreRing(
                            data: data,
                            isLoading: isLoading,
                            profileId: _activeProfileId,
                            onTap: _activeProfileId != null
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TrendChartScreen(profileId: _activeProfileId!),
                                      ),
                                    )
                                : null,
                            onInfoTap: () {
                              final score = (data?['score'] as num?)?.toInt() ?? 50;
                              final flagData = helpers.computeFlag(
                                score: score,
                                bpStatus: data?['today_bp_status'] as String?,
                                glucoseStatus: data?['today_glucose_status'] as String?,
                                age: (data?['profile_age'] as num?)?.toInt(),
                              );
                              showStatusInfoSheet(context, flagData, l10n);
                            },
                          ),
                          const SizedBox(height: 16),
                          VitalSummaryCard(data: data),
                          const SizedBox(height: 16),
                          if (_aiInsightFuture != null)
                            AiInsightCard(
                              insightFuture: _aiInsightFuture,
                              pulseAnimation: _pulseAnimation,
                              isSaved: _insightSaved,
                              onSaveToggle: () => setState(() => _insightSaved = !_insightSaved),
                            ),
                          const SizedBox(height: 16),
                          if (_activeProfile?.doctorName?.isNotEmpty == true)
                            PhysicianCard(
                              profile: _activeProfile!,
                              onWhatsAppTap: _activeProfile!.doctorWhatsapp?.isNotEmpty == true
                                  ? () => _openWhatsApp(_activeProfile!.doctorWhatsapp!)
                                  : null,
                            ),
                          if (_activeProfile?.doctorName?.isNotEmpty == true)
                            const SizedBox(height: 16),
                          MetricsGrid(
                            data: data,
                            profileId: _activeProfileId,
                            canEdit: _accessLevel != 'viewer',
                            onAddReading: _handleAddReading,
                            onArmBandTap: () {
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
}
