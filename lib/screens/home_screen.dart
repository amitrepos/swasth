import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'select_profile_screen.dart';
import 'manage_access_screen.dart';
import 'scan_screen.dart';
import 'photo_scan_screen.dart';
import 'reading_confirmation_screen.dart';
import 'trend_chart_screen.dart';
import '../services/storage_service.dart';
import '../services/health_reading_service.dart';
import '../theme/app_theme.dart';
import '../main.dart' show routeObserver;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final StorageService _storageService = StorageService();
  final HealthReadingService _readingService = HealthReadingService();
  String _activeProfileName = "Health";
  int? _activeProfileId;
  Future<Map<String, dynamic>>? _healthScoreFuture;
  Future<String>? _aiInsightFuture;

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when the user navigates back to this screen (e.g. from History or Profile).
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
    setState(() {
      _healthScoreFuture = _readingService.getHealthScore(token, profileId);
      _aiInsightFuture = _readingService.getAiInsight(token, profileId);
    });
  }

  Future<void> _logout(BuildContext context) async {
    await _storageService.clearAll();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              if (_activeProfileId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(profileId: _activeProfileId!),
                  ),
                );
              }
            },
            tooltip: l10n.profile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: l10n.logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Active Profile Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.account_circle, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.viewingProfile(_activeProfileName),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.person_add_alt_1,
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    tooltip: l10n.shareProfile,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      if (_activeProfileId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageAccessScreen(
                              profileId: _activeProfileId!,
                              profileName: _activeProfileName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SelectProfileScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.switchProfile),
                  ),
                ],
              ),
            ),

            // Health Score Card
            if (_healthScoreFuture != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _HealthScoreCard(
                  future: _healthScoreFuture!,
                  onRefresh: () {
                    if (_activeProfileId != null) _refreshHealthScore(_activeProfileId!);
                  },
                  onTap: _activeProfileId != null
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrendChartScreen(profileId: _activeProfileId!),
                            ),
                          )
                      : null,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: _HealthScoreCard.empty(),
              ),

            // AI Doctor Card
            if (_aiInsightFuture != null)
              _AIDoctorCard(insightFuture: _aiInsightFuture!),

            // Device Selection Panel
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 0.5,
                ),
                boxShadow: Theme.of(context).brightness == Brightness.light
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      l10n.selectDevice,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDeviceIcon(
                        context: context,
                        icon: Icons.water_drop,
                        label: l10n.glucometer,
                        color: AppColors.glucose,
                        onTap: () => _showInputModal(
                          context,
                          l10n: l10n,
                          deviceType: 'glucose',
                          btDeviceType: 'Glucose',
                        ),
                      ),
                      _buildDeviceIcon(
                        context: context,
                        icon: Icons.favorite,
                        label: l10n.bpMeter,
                        color: AppColors.bloodPressure,
                        onTap: () => _showInputModal(
                          context,
                          l10n: l10n,
                          deviceType: 'blood_pressure',
                          btDeviceType: 'Blood Pressure',
                        ),
                      ),
                      _buildDeviceIcon(
                        context: context,
                        icon: Icons.watch,
                        label: l10n.armband,
                        color: AppColors.iosGreen,
                        onTap: () {
                          if (_activeProfileId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DashboardScreen(
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
                    ],
                  ),
                ],
              ),
            ),

            // Quick Actions
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.quickActions,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.bluetooth_searching, color: Theme.of(context).colorScheme.primary),
                      title: Text(l10n.connectNewDevice),
                      subtitle: Text(l10n.connectNewDeviceSubtitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        if (_activeProfileId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScanScreen(profileId: _activeProfileId!),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.selectProfileFirst)),
                          );
                        }
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                      title: Text(l10n.viewHistory),
                      subtitle: Text(l10n.viewHistorySubtitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        if (_activeProfileId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryScreen(profileId: _activeProfileId!),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.show_chart, color: Theme.of(context).colorScheme.primary),
                      title: Text(l10n.viewTrends),
                      subtitle: Text(l10n.viewTrendsSubtitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        if (_activeProfileId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TrendChartScreen(profileId: _activeProfileId!),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.howToLog,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
                  if (mounted && _activeProfileId != null) _refreshHealthScore(_activeProfileId!);
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
                  if (mounted && _activeProfileId != null) _refreshHealthScore(_activeProfileId!);
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
                  if (mounted && _activeProfileId != null) _refreshHealthScore(_activeProfileId!);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIcon({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(
                color: color,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Doctor Card widget
// ---------------------------------------------------------------------------

class _AIDoctorCard extends StatelessWidget {
  final Future<String> insightFuture;

  const _AIDoctorCard({required this.insightFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: insightFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final text = snapshot.data ?? '';
        if (text.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withOpacity(0.25), width: 1),
            boxShadow: Theme.of(context).brightness == Brightness.light
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🩺', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'AI Doctor',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '— Powered by Gemini —',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Health Score Card widget
// ---------------------------------------------------------------------------

class _HealthScoreCard extends StatelessWidget {
  final Future<Map<String, dynamic>>? future;
  final VoidCallback? onRefresh;
  final VoidCallback? onTap;

  const _HealthScoreCard({
    required Future<Map<String, dynamic>> future,
    required VoidCallback onRefresh,
    this.onTap,
  })  : future = future,
        onRefresh = onRefresh;

  const _HealthScoreCard.empty()
      : future = null,
        onRefresh = null,
        onTap = null;

  static Color _scoreColor(String? color) {
    switch (color) {
      case 'green':  return AppColors.statusNormal;
      case 'orange': return AppColors.statusElevated;
      case 'red':    return AppColors.statusHigh;
      default:       return AppColors.statusLow;
    }
  }

  static String _formatLastLogged(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today, ${DateFormat('h:mm a').format(dt)}';
      }
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  static String _statusIcon(String? status) {
    if (status == null) return '';
    if (status == 'NORMAL') return ' ✅';
    if (status.contains('HIGH') || status == 'CRITICAL') return ' ⚠️';
    if (status == 'LOW') return ' 🔽';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (future == null) return _buildEmpty(context, l10n);

    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmer(context);
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildEmpty(context, l10n);
        }
        return _buildCard(context, l10n, snapshot.data!);
      },
    );
  }

  Widget _buildCard(BuildContext context, AppLocalizations l10n, Map<String, dynamic> data) {
    final score = (data['score'] as num?)?.toInt() ?? 50;
    final color = data['color'] as String? ?? 'orange';
    final streak = (data['streak_days'] as num?)?.toInt() ?? 0;
    final insight = data['insight'] as String? ?? '';
    final glucoseValue = (data['today_glucose_value'] as num?)?.toDouble();
    final glucoseStatus = data['today_glucose_status'] as String?;
    final bpSystolic = (data['today_bp_systolic'] as num?)?.toDouble();
    final bpDiastolic = (data['today_bp_diastolic'] as num?)?.toDouble();
    final bpStatus = data['today_bp_status'] as String?;
    final lastLogged = _formatLastLogged(data['last_logged'] as String?);
    final scoreColor = _scoreColor(color);

    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.3), width: 1.5),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.healthScore,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🔥 ${l10n.dayStreak(streak)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Score ring + insight
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 8,
                        backgroundColor: scoreColor.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: scoreColor),
                        ),
                        Text('/100', style: TextStyle(fontSize: 10, color: scoreColor.withOpacity(0.7))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  insight,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          // Today's readings
          if (glucoseValue != null || bpSystolic != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (glucoseValue != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Text('🩸', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.todayGlucose,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Text(
                              '${glucoseValue.toStringAsFixed(0)} mg/dL${_statusIcon(glucoseStatus)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (bpSystolic != null && bpDiastolic != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Text('💓', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.todayBP,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Text(
                              '${bpSystolic.toStringAsFixed(0)}/${bpDiastolic.toStringAsFixed(0)}${_statusIcon(bpStatus)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          if (lastLogged.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.lastLogged(lastLogged),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],

          if (onTap != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Center(
              child: Text(
                l10n.tapToViewTrends,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: card,
          )
        : card;
  }

  Widget _buildShimmer(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              l10n.noReadingsYetScore,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
