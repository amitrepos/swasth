// Context: Streaks tab — shows streak count, points, and weekly leaderboard.
// Placeholder until gamification backend is built (Phase 8).

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/storage_service.dart';
import '../services/health_reading_service.dart';

class StreaksScreen extends StatefulWidget {
  const StreaksScreen({super.key});

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  int _streak = 0;
  int _pts = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storage = StorageService();
      final token = await storage.getToken();
      final profileId = await storage.getActiveProfileId();
      if (token == null || profileId == null) return;
      final data = await HealthReadingService().getHealthScore(token, profileId);
      if (mounted) {
        final streak = (data['streak_days'] as num?)?.toInt() ?? 0;
        setState(() {
          _streak = streak;
          _pts = _streakToPoints(streak);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static int _streakToPoints(int streak) {
    if (streak >= 30) return 1500;
    if (streak >= 14) return 700;
    if (streak >= 7)  return 300;
    if (streak >= 3)  return 100;
    if (streak >= 1)  return 10;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STREAKS & POINTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Streak card
                GlassCard(
                  borderRadius: 28,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 12),
                      Text(
                        '$_streak',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'DAY STREAK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _streakMessage(_streak),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Points card
                GlassCard(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 40)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_pts pts',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Total Points Earned',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Milestones
                GlassCard(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MILESTONES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Milestone(days: 1, pts: 10, reached: _streak >= 1),
                      _Milestone(days: 3, pts: 100, reached: _streak >= 3),
                      _Milestone(days: 7, pts: 300, reached: _streak >= 7),
                      _Milestone(days: 14, pts: 700, reached: _streak >= 14),
                      _Milestone(days: 30, pts: 1500, reached: _streak >= 30),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _streakMessage(int streak) {
    if (streak == 0) return 'Log a reading today to start your streak!';
    if (streak == 1) return 'Great start! Come back tomorrow.';
    if (streak < 7)  return 'Keep going — $streak days and counting!';
    if (streak < 14) return '🔥 One week strong! You\'re building a great habit.';
    if (streak < 30) return '🌟 ${streak}-day streak! You\'re a health champion.';
    return '🏆 ${streak} days! You\'re in the top tier.';
  }
}

class _Milestone extends StatelessWidget {
  final int days;
  final int pts;
  final bool reached;

  const _Milestone({required this.days, required this.pts, required this.reached});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            reached ? Icons.check_circle : Icons.radio_button_unchecked,
            color: reached ? AppColors.success : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$days-day streak',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: reached ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: reached ? AppColors.amber.withValues(alpha: 0.15) : AppColors.bgGrouped,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$pts pts',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: reached ? AppColors.amber : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
