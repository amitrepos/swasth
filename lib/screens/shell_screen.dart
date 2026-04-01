// Context: 5-tab navigation shell. Wraps Home, History, Streaks, Insights, Chat.
// Architecture: IndexedStack (preserves scroll/state per tab).
// Related: home_screen.dart, history_screen.dart, trend_chart_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_banner.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'streaks_screen.dart';
import 'insights_screen.dart';
import 'chat_screen.dart';
import 'select_profile_screen.dart';
import 'profile_screen.dart';
import 'manage_access_screen.dart';
import 'login_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  /// Switch to a tab from outside the shell (e.g. "Discuss with AI").
  static void switchToTab(int index) {
    _ShellScreenState._instance?._onTap(index);
  }

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static _ShellScreenState? _instance;
  int _currentIndex = 0;
  int? _profileId;
  String _profileName = '';
  bool _loading = true;
  bool _isOffline = false;
  Timer? _connectivityTimer;
  Timer? _profileRefreshTimer;

  @override
  void initState() {
    super.initState();
    _instance = this;
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
    _connectivityTimer?.cancel();
    _profileRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshProfileIfChanged() async {
    final storage = StorageService();
    final id = await storage.getActiveProfileId();
    if (id != null && id != _profileId && mounted) {
      final name = await storage.getActiveProfileName() ?? 'Health';
      setState(() { _profileId = id; _profileName = name; });
    }
  }

  Future<void> _logout() async {
    await StorageService().clearAll();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _checkConnectivity() async {
    final reachable = await ConnectivityService().isServerReachable();
    if (!mounted) return;
    final wasOffline = _isOffline;
    setState(() => _isOffline = !reachable);
    // Auto-sync when coming back online
    if (wasOffline && reachable) {
      SyncService().syncPendingReadings();
    }
  }

  Future<void> _loadProfile() async {
    final storage = StorageService();
    final id = await storage.getActiveProfileId();
    if (!mounted) return;
    if (id == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SelectProfileScreen()),
      );
      return;
    }
    final name = await storage.getActiveProfileName() ?? 'Health';
    setState(() {
      _profileId = id;
      _profileName = name;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profileId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          if (_isOffline) const OfflineBanner(),

          // ── Persistent header bar (visible on all tabs) ────────────
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
              ),
              child: Row(
                children: [
                  // Profile avatar
                  GestureDetector(
                    onTap: () {
                      if (_profileId != null) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ProfileScreen(profileId: _profileId!),
                        ));
                      }
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        _profileName.isNotEmpty ? _profileName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Profile name — tap to view profile
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_profileId != null) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ProfileScreen(profileId: _profileId!),
                          ));
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _profileName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  // Switch profile
                  IconButton(
                    icon: const Icon(Icons.switch_account, size: 22),
                    color: AppColors.textSecondary,
                    tooltip: 'Switch Profile',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SelectProfileScreen()),
                    ),
                  ),
                  // Share / manage access
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    color: AppColors.textSecondary,
                    tooltip: 'Share Profile',
                    onPressed: () {
                      if (_profileId != null) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ManageAccessScreen(
                            profileId: _profileId!,
                            profileName: _profileName,
                          ),
                        ));
                      }
                    },
                  ),
                  // Logout
                  IconButton(
                    icon: const Icon(Icons.logout, size: 20),
                    color: AppColors.statusCritical,
                    tooltip: 'Logout',
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                const HomeScreen(),
                HistoryScreen(key: ValueKey('history_$_profileId'), profileId: _profileId!),
                const StreaksScreen(),
                InsightsScreen(key: ValueKey('insights_$_profileId'), profileId: _profileId!),
                ChatScreen(key: ValueKey('chat_$_profileId'), profileId: _profileId!),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
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
              _NavItem(index: 0, current: _currentIndex, emoji: '🏠', label: 'HOME', onTap: _onTap),
              _NavItem(index: 1, current: _currentIndex, emoji: '📊', label: 'HISTORY', onTap: _onTap),
              _NavItem(index: 2, current: _currentIndex, emoji: '🔥', label: 'STREAKS', onTap: _onTap),
              _NavItem(index: 3, current: _currentIndex, emoji: '📈', label: 'INSIGHTS', onTap: _onTap),
              _NavItem(index: 4, current: _currentIndex, emoji: '💬', label: 'CHAT', onTap: _onTap),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(int index) => setState(() => _currentIndex = index);
}

class _NavItem extends StatelessWidget {
  final int index;
  final int current;
  final String emoji;
  final String label;
  final void Function(int) onTap;

  const _NavItem({
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
