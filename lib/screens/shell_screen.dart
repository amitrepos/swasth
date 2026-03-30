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

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;
  int? _profileId;
  bool _loading = true;
  bool _isOffline = false;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnectivity(),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
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
    final id = await StorageService().getActiveProfileId();
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

    return Scaffold(
      body: Column(
        children: [
          if (_isOffline) const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                const HomeScreen(),
                HistoryScreen(profileId: _profileId!),
                const StreaksScreen(),
                InsightsScreen(profileId: _profileId!),
                const ChatScreen(),
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
