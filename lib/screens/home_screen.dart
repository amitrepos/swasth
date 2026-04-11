// Context: Main dashboard — glassmorphism redesign matching dashboard1.html.
// Related: lib/widgets/glass_card.dart, lib/theme/app_theme.dart, backend/routes_health.py

import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

import 'select_profile_screen.dart';
import 'manage_access_screen.dart';
import 'trend_chart_screen.dart';
import 'scan_screen.dart';
import 'shell_screen.dart';
import '../services/storage_service.dart';
import '../services/health_reading_service.dart';
import '../services/profile_service.dart';
import '../services/doctor_service.dart';
import '../services/sync_service.dart';
import 'link_doctor_screen.dart';
import '../models/profile_model.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/health_score_ring.dart';
import '../widgets/home/ai_insight_card.dart';
import '../widgets/home/physician_card.dart';
import '../widgets/home/linked_doctors_card.dart';
import '../widgets/home/vital_summary_card.dart';
import '../widgets/home/metrics_grid.dart';
import '../widgets/home/reading_input_modal.dart';
import '../widgets/home/meal_input_modal.dart';
import '../widgets/home/meal_summary_card.dart';
import '../widgets/home/device_status_card.dart';
import '../widgets/home/activity_feed_card.dart';
import '../widgets/home/care_circle_card.dart';
import '../config/feature_flags.dart';
import '../utils/health_helpers.dart' as helpers;
import '../services/reminder_service.dart';
import '../main.dart' show routeObserver;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

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
  final DoctorService _doctorService = DoctorService();
  List<Map<String, dynamic>> _linkedDoctors = [];

  String _activeProfileName = "Health";
  int? _activeProfileId;
  String _accessLevel = "owner";
  Future<Map<String, dynamic>>? _healthScoreFuture;
  Future<String>? _aiInsightFuture;
  ProfileModel? _activeProfile;

  int _streak = 0;
  int _pts = 0;
  bool _insightSaved = false;

  // Caregiver dashboard state
  List<HealthReading> _activityReadings = [];
  List<Map<String, dynamic>> _careCircleMembers = [];
  bool _careCircleLoading = false;
  bool _activityLoading = false;
  String? _currentUserEmail;
  bool _showFullDashboard = false;

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
    // Re-read active profile from storage in case it changed
    _loadProfileInfo();
  }

  Future<void> _loadProfileInfo() async {
    final name = await _storageService.getActiveProfileName();
    final id = await _storageService.getActiveProfileId();
    final level = await _storageService.getActiveProfileAccessLevel();
    final userData = await _storageService.getUserData();
    if (mounted) {
      setState(() {
        if (name != null) _activeProfileName = name;
        _activeProfileId = id;
        _accessLevel = level ?? 'owner';
        _currentUserEmail = userData?['email'] as String?;
        _showFullDashboard = false; // Reset on profile switch
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

    _loadLinkedDoctors(token, profileId);

    // Load caregiver-specific data when viewing shared profile
    if (_isCaregiverView) {
      _loadCaregiverData(token, profileId);
    }
  }

  Future<void> _loadLinkedDoctors(String token, int profileId) async {
    try {
      final raw = await _doctorService.getLinkedDoctors(token, profileId);
      if (!mounted) return;
      setState(() {
        _linkedDoctors = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() => _linkedDoctors = []);
    }
  }

  Future<void> _openLinkDoctorScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LinkDoctorScreen()),
    );
    final token = await _storageService.getToken();
    if (token != null && _activeProfileId != null) {
      _loadLinkedDoctors(token, _activeProfileId!);
    }
  }

  bool get _isCaregiverView =>
      FeatureFlags.caregiverDashboard &&
      _accessLevel != 'owner' &&
      !_showFullDashboard;

  Future<void> _loadCaregiverData(String token, int profileId) async {
    setState(() {
      _activityLoading = true;
      _careCircleLoading = true;
    });

    // Load recent readings for activity feed
    try {
      final readings = await _readingService.getReadings(
        token: token,
        profileId: profileId,
        limit: 10,
      );
      if (mounted) setState(() => _activityReadings = readings);
    } catch (_) {}
    if (mounted) setState(() => _activityLoading = false);

    // Load care circle members
    try {
      final members = await _profileService.getProfileAccess(token, profileId);
      if (mounted) setState(() => _careCircleMembers = members);
    } catch (_) {}
    if (mounted) setState(() => _careCircleLoading = false);
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

  Future<void> _callDoctor(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  final GlobalKey<MealSummaryCardState> _mealSummaryKey =
      GlobalKey<MealSummaryCardState>();

  void _handleAddMeal() {
    if (_activeProfileId == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectProfileFirst)));
      return;
    }
    showMealInputModal(
      context,
      profileId: _activeProfileId!,
      onMealSaved: () {
        if (mounted && _activeProfileId != null) {
          _refreshHealthScore(_activeProfileId!);
          _mealSummaryKey.currentState?.loadMeals();
        }
      },
    );
  }

  void _handleAddReading({
    required String deviceType,
    required String btDeviceType,
  }) {
    if (_activeProfileId == null) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectProfileFirst)));
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
            if (_activeProfileId != null)
              _refreshHealthScore(_activeProfileId!);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeHeader(
                  key: const Key('dashboard_header'),
                  activeProfileName: _activeProfileName,
                  activeProfileId: _activeProfileId,
                  streak: _streak,
                  pts: _pts,
                  onSwitchProfile: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const SelectProfileScreen(pushedFromShell: true),
                    ),
                  ),
                  onViewProfile: () {
                    if (_activeProfileId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(profileId: _activeProfileId!),
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
                          builder: (_) =>
                              ProfileScreen(profileId: _activeProfileId!),
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

                      if (_isCaregiverView) {
                        return _buildCaregiverDashboard(data, isLoading, l10n);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // "Back to Wellness Hub" banner when in full dashboard mode
                          if (_showFullDashboard &&
                              FeatureFlags.caregiverDashboard &&
                              _accessLevel != 'owner')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _showFullDashboard = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_back_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          l10n.backToWellnessHub,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.monitor_heart_outlined,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          HealthScoreRing(
                            key: const Key('dashboard_health_score'),
                            data: data,
                            isLoading: isLoading,
                            profileId: _activeProfileId,
                            onTap: _activeProfileId != null
                                ? () async {
                                    final result = await Navigator.push<String>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TrendChartScreen(
                                          profileId: _activeProfileId!,
                                        ),
                                      ),
                                    );
                                    if (result == 'open_chat' && mounted) {
                                      ShellScreen.switchToTab(4);
                                    }
                                  }
                                : null,
                            onCallDoctor:
                                _activeProfile?.doctorWhatsapp?.isNotEmpty ==
                                    true
                                ? () => _callDoctor(
                                    _activeProfile!.doctorWhatsapp!,
                                  )
                                : null,
                            onInfoTap: () {
                              final score =
                                  (data?['score'] as num?)?.toInt() ?? 50;
                              final flagData = helpers.computeFlag(
                                score: score,
                                bpStatus: data?['today_bp_status'] as String?,
                                glucoseStatus:
                                    data?['today_glucose_status'] as String?,
                                age: (data?['profile_age'] as num?)?.toInt(),
                              );
                              showStatusInfoSheet(context, flagData, l10n);
                            },
                          ),
                          const SizedBox(height: 16),

                          // ② Vitals 2x2 grid (BP, Sugar, BMI, Steps)
                          MetricsGrid(
                            key: const Key('dashboard_metrics_grid'),
                            data: data,
                            profileId: _activeProfileId,
                            canEdit: _accessLevel != 'viewer',
                            onAddReading: _handleAddReading,
                            bmi: (data?['bmi'] as num?)?.toDouble(),
                            bmiCategory: data?['bmi_category'] as String?,
                            heightCm: (data?['profile_height'] as num?)
                                ?.toDouble(),
                            weightKg: (data?['profile_weight'] as num?)
                                ?.toDouble(),
                          ),
                          const SizedBox(height: 16),

                          // ④ Today's Meals (expanded with slot prompts)
                          if (_activeProfileId != null)
                            KeyedSubtree(
                              key: const Key('dashboard_meal_summary'),
                              child: MealSummaryCard(
                                key: _mealSummaryKey,
                                profileId: _activeProfileId!,
                                onTapLogMeal: _handleAddMeal,
                              ),
                            ),
                          if (_activeProfileId != null)
                            const SizedBox(height: 16),

                          // ⑤ AI Insight (collapsed, 2 lines + Read more)
                          if (_aiInsightFuture != null)
                            AiInsightCard(
                              key: const Key('dashboard_ai_insight'),
                              insightFuture: _aiInsightFuture,
                              pulseAnimation: _pulseAnimation,
                              isSaved: _insightSaved,
                              onSaveToggle: () => setState(
                                () => _insightSaved = !_insightSaved,
                              ),
                            ),
                          if (_aiInsightFuture != null)
                            const SizedBox(height: 16),

                          // ⑥ Physician Card — prefer DoctorPatientLink
                          // (new system); fall back to legacy free-text
                          // doctor_name on the profile if no link exists.
                          // Always renders something (filled, legacy, or
                          // empty-state CTA) so the section can never
                          // silently disappear.
                          if (_linkedDoctors.isNotEmpty)
                            LinkedDoctorsCard(
                              key: const Key('dashboard_doctor_section'),
                              linkedDoctors: _linkedDoctors,
                              onLinkDoctorTap: _openLinkDoctorScreen,
                            )
                          else if (_activeProfile?.doctorName?.isNotEmpty ==
                              true)
                            PhysicianCard(
                              key: const Key('dashboard_doctor_section'),
                              profile: _activeProfile!,
                              onWhatsAppTap:
                                  _activeProfile!.doctorWhatsapp?.isNotEmpty ==
                                      true
                                  ? () => _openWhatsApp(
                                      _activeProfile!.doctorWhatsapp!,
                                    )
                                  : null,
                            )
                          else
                            LinkedDoctorsCard(
                              key: const Key('dashboard_doctor_section'),
                              linkedDoctors: const [],
                              onLinkDoctorTap: _openLinkDoctorScreen,
                            ),
                          const SizedBox(height: 16),

                          // ⑦ Device Status Card
                          const DeviceStatusCard(
                            key: Key('dashboard_device_status'),
                          ),
                          const SizedBox(height: 16),

                          // ⑧ 90-day Trends (pushed down)
                          VitalSummaryCard(
                            key: const Key('dashboard_vital_summary'),
                            data: data,
                          ),
                          const SizedBox(height: 16),

                          // ⑨ Quick actions
                          KeyedSubtree(
                            key: const Key('dashboard_quick_actions'),
                            child: _buildQuickActions(l10n),
                          ),
                          const SizedBox(height: 16),

                          KeyedSubtree(
                            key: const Key('dashboard_footer'),
                            child: _buildFooter(l10n),
                          ),
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

  // ── Caregiver Dashboard ──────────────────────────────────────────────────

  Widget _buildCaregiverDashboard(
    Map<String, dynamic>? data,
    bool isLoading,
    AppLocalizations l10n,
  ) {
    final relationship = _activeProfile?.relationship ?? '';
    final relDisplay = relationship.isNotEmpty
        ? _capitalize(relationship)
        : 'Family Member';
    final profileName = _activeProfileName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ① Caregiver header
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(16),
          margin: EdgeInsets.zero,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.wellnessHubTitle(relDisplay),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profileName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons (right side)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Take Readings button
                  if (_accessLevel == 'editor' || _accessLevel == 'owner')
                    GestureDetector(
                      onTap: () => setState(() => _showFullDashboard = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.takeReadings,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_activeProfile?.doctorWhatsapp?.isNotEmpty == true)
                    const SizedBox(height: 8),
                  // Priority call button
                  if (_activeProfile?.doctorWhatsapp?.isNotEmpty == true)
                    GestureDetector(
                      onTap: () => _callDoctor(_activeProfile!.doctorWhatsapp!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.statusCritical.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: AppColors.statusCritical,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.priorityCall,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.statusCritical,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ② Wellness Ring with personalized message
        HealthScoreRing(
          data: data,
          isLoading: isLoading,
          profileId: _activeProfileId,
          relationship: relDisplay,
          onTap: _activeProfileId != null
              ? () async {
                  final result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TrendChartScreen(profileId: _activeProfileId!),
                    ),
                  );
                  if (result == 'open_chat' && mounted) {
                    ShellScreen.switchToTab(4);
                  }
                }
              : null,
          onCallDoctor: _activeProfile?.doctorWhatsapp?.isNotEmpty == true
              ? () => _callDoctor(_activeProfile!.doctorWhatsapp!)
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

        // ③ Activity Feed
        ActivityFeedCard(
          readings: _activityReadings,
          isLoading: _activityLoading,
        ),
        const SizedBox(height: 16),

        // ④ 90-day Trends
        VitalSummaryCard(data: data),
        const SizedBox(height: 16),

        // ⑤ Care Circle
        CareCircleCard(
          members: _careCircleMembers,
          isLoading: _careCircleLoading,
          currentUserEmail: _currentUserEmail,
        ),
        const SizedBox(height: 16),

        // ⑥ Physician Card — prefer DoctorPatientLink (new system);
        // fall back to legacy free-text doctor_name on the profile.
        if (_linkedDoctors.isNotEmpty)
          LinkedDoctorsCard(
            linkedDoctors: _linkedDoctors,
            onLinkDoctorTap: _openLinkDoctorScreen,
          )
        else if (_activeProfile?.doctorName?.isNotEmpty == true)
          PhysicianCard(
            profile: _activeProfile!,
            onWhatsAppTap: _activeProfile!.doctorWhatsapp?.isNotEmpty == true
                ? () => _openWhatsApp(_activeProfile!.doctorWhatsapp!)
                : null,
          )
        else
          LinkedDoctorsCard(
            linkedDoctors: const [],
            onLinkDoctorTap: _openLinkDoctorScreen,
          ),
        const SizedBox(height: 16),

        _buildFooter(l10n),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildQuickActions(AppLocalizations l10n) {
    return Row(
      children: [
        // Reminder toggle
        Expanded(
          child: GestureDetector(
            onTap: () => _showReminderDialog(context),
            child: GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Reminder',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Share weekly summary
        Expanded(
          child: GestureDetector(
            onTap: () => _shareWeeklySummary(),
            child: GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.share, size: 18, color: AppColors.success),
                  const SizedBox(height: 4),
                  const Text(
                    'Summary',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Pair Device
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScanScreen(profileId: _activeProfileId ?? 0),
                ),
              );
            },
            child: GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.watch, size: 18, color: AppColors.amber),
                  const SizedBox(height: 4),
                  Text(
                    l10n.pairDevice,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showReminderDialog(BuildContext ctx) async {
    final reminder = ReminderService();
    final enabled = await reminder.isEnabled();
    final hour = await reminder.getHour();
    final minute = await reminder.getMinute();

    if (!mounted) return;
    final time = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      helpText: enabled
          ? 'Change reminder time (or cancel to disable)'
          : 'Set daily reminder time',
    );

    if (time != null) {
      await reminder.enableReminder(time.hour, time.minute);
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Reminder set for ${time.format(ctx)} daily')),
        );
      }
    } else if (enabled) {
      await reminder.disableReminder();
      if (mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('Reminder disabled')));
      }
    }
  }

  Future<void> _shareWeeklySummary() async {
    if (_activeProfileId == null) return;
    final token = await _storageService.getToken();
    if (token == null) return;

    final data = await _readingService.getWeeklySummary(
      token,
      _activeProfileId!,
    );
    final text = data['summary_text'] as String? ?? 'No summary available';

    Share.share(text);
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
          const Icon(
            Icons.health_and_safety_outlined,
            size: 48,
            color: AppColors.primary,
          ),
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
              MaterialPageRoute(
                builder: (_) =>
                    const SelectProfileScreen(pushedFromShell: true),
              ),
            ),
            child: Text(l10n.switchProfile),
          ),
        ],
      ),
    );
  }
}
