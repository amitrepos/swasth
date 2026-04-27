// Context: 5-tab navigation shell. Wraps Home, History, Streaks, Insights, Chat.
// Architecture: IndexedStack (preserves scroll/state per tab).
// Related: home_screen.dart, history_screen.dart, trend_chart_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';
import '../services/error_mapper.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_banner.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'streaks_screen.dart';
import 'trend_chart_screen.dart';
import 'chat_screen.dart';
import 'select_profile_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  /// Switch to a tab from outside the shell (e.g. "Discuss with AI").
  /// If chatMessage is provided and index is 4 (Chat), rebuilds Chat with that message.
  static void switchToTab(int index, {String? chatMessage}) {
    final state = _ShellScreenState._instance;
    if (state == null) return;
    if (index == 4 && chatMessage != null) {
      state.setState(() => state._currentIndex = index);
      // Send message directly into the existing Chat state — no full rebuild needed
      Future.microtask(
        () => state._chatKey.currentState?.sendInitialMessage(chatMessage),
      );
    } else {
      state._onTap(index);
    }
  }

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with WidgetsBindingObserver {
  static _ShellScreenState? _instance;
  int _currentIndex = 0;
  int? _profileId;
  bool _loading = true;
  bool _isOffline = false;
  Timer? _connectivityTimer;
  Timer? _profileRefreshTimer;
  final _historyKey = GlobalKey<HistoryScreenState>();
  final _insightsKey = GlobalKey<TrendChartScreenState>();
  final _chatKey = GlobalKey<ChatScreenState>();

  @override
  void initState() {
    super.initState();
    _instance = this;
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _checkConnectivity();
    // Listen for profile switches from other screens
    _profileRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshProfileIfChanged(),
    );
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnectivity(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivityTimer?.cancel();
    _profileRefreshTimer?.cancel();
    if (_instance == this) _instance = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _validateSession();
  }

  Future<void> _validateSession() async {
    final token = await StorageService().getToken();
    if (token == null || !mounted) return;
    try {
      await ApiService().getCurrentUser(token);
    } on UnauthorizedException catch (e) {
      if (mounted) await ErrorMapper.showSnack(context, e);
    } catch (_) {
      // Network errors — offline, don't force logout
    }
  }

  Future<void> _refreshProfileIfChanged() async {
    if (!mounted) return;
    final storage = StorageService();
    final id = await storage.getActiveProfileId();
    if (!mounted) return;
    if (id != null && id != _profileId) {
      if (!mounted) return;
      setState(() {
        _profileId = id;
      });
    }
  }

  // Logout functionality removed - not currently used

  Future<void> _checkConnectivity() async {
    if (!mounted) return;
    final reachable = await ConnectivityService().isServerReachable();
    if (!mounted) return;
    final wasOffline = _isOffline;
    setState(() => _isOffline = !reachable);
    
    // Show snackbar when coming back online
    if (wasOffline && reachable && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done, color: Colors.white),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.backOnline),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    // Auto-sync when coming back online
    if (wasOffline && reachable) {
      final result = await SyncService().syncPendingReadings();
      if (result.authExpired && mounted) {
        await ErrorMapper.showSnack(context, const UnauthorizedException());
      }
    }
  }

  Future<void> _loadProfile() async {
    final storage = StorageService();
    var id = await storage.getActiveProfileId();
    // Retry once if null — storage may not have flushed yet
    if (id == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      id = await storage.getActiveProfileId();
    }
    if (!mounted) return;
    if (id == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SelectProfileScreen()),
      );
      return;
    }
    setState(() {
      _profileId = id;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profileId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Column(
          children: [
            if (_isOffline) const OfflineBanner(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  const HomeScreen(),
                  HistoryScreen(key: _historyKey, profileId: _profileId!),
                  StreaksScreen(key: ValueKey('streaks_$_profileId')),
                  TrendChartScreen(
                    key: _insightsKey,
                    profileId: _profileId!,
                  ),
                  ChatScreen(
                    key: _chatKey,
                    profileId: _profileId!,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
        boxShadow: [BoxShadow(color: AppColors.glassShadow, blurRadius: 16)],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                key: const Key('nav_home'),
                index: 0,
                current: _currentIndex,
                emoji: '🏠',
                label: 'HOME',
                onTap: _onTap,
              ),
              _NavItem(
                key: const Key('nav_history'),
                index: 1,
                current: _currentIndex,
                emoji: '📊',
                label: 'HISTORY',
                onTap: _onTap,
              ),
              _NavItem(
                key: const Key('nav_streaks'),
                index: 2,
                current: _currentIndex,
                emoji: '🔥',
                label: 'STREAKS',
                onTap: _onTap,
              ),
              _NavItem(
                key: const Key('nav_insights'),
                index: 3,
                current: _currentIndex,
                emoji: '📈',
                label: 'INSIGHTS',
                onTap: _onTap,
              ),
              _NavItem(
                key: const Key('nav_chat'),
                index: 4,
                current: _currentIndex,
                emoji: '💬',
                label: 'CHAT',
                onTap: _onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) _historyKey.currentState?.refresh();
    if (index == 3) _insightsKey.currentState?.refresh();
    if (index == 4) _chatKey.currentState?.refreshVitals();
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int current;
  final String emoji;
  final String label;
  final void Function(int) onTap;

  const _NavItem({
    super.key,
    required this.index,
    required this.current,
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 16 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
