// Context: Streaks tab — streak, points, weekly calendar, family leaderboard.
// Related: routes_health.py GET /readings/family-streaks

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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
  List<Map<String, dynamic>> _leaderboard = [];
  int? _activeProfileId;
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
      if (token == null) return;
      final board = await HealthReadingService().getFamilyStreaks(token);
      if (mounted) {
        setState(() {
          _leaderboard = board;
          _activeProfileId = profileId;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _myData {
    if (_activeProfileId == null) return null;
    try {
      return _leaderboard.firstWhere((e) => e['profile_id'] == _activeProfileId);
    } catch (_) {
      return _leaderboard.isNotEmpty ? _leaderboard.first : null;
    }
  }

  void _shareStreak() {
    final data = _myData;
    if (data == null) return;
    final streak = data['streak_days'] ?? 0;
    final pts = data['points'] ?? 0;
    final name = data['profile_name'] ?? 'I';
    Share.share(
      '$name has been tracking health for $streak days straight! 🔥\n'
      '$pts points earned. Join Swasth to start your health journey!',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final my = _myData;
    final streak = (my?['streak_days'] as num?)?.toInt() ?? 0;
    final pts = (my?['points'] as num?)?.toInt() ?? 0;
    final weekActivity = List<Map<String, dynamic>>.from(my?['week_activity'] ?? []);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Streak + Points hero card ──────────────────────────
              GlassCard(
                borderRadius: 28,
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text(
                      '$streak',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'DAY STREAK',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _streakMessage(streak),
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '🏆 $pts pts',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.amber),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _shareStreak,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('Share', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
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

              // ── Weekly activity calendar ───────────────────────────
              if (weekActivity.isNotEmpty)
                GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THIS WEEK',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 2),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: weekActivity.map((day) {
                          final hasReading = day['has_reading'] == true;
                          final weekday = (day['weekday'] as String?)?.substring(0, 1) ?? '?';
                          return Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: hasReading ? AppColors.success : AppColors.bgGrouped,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: hasReading
                                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                                      : Text(weekday, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                weekday,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: hasReading ? AppColors.success : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              if (weekActivity.isNotEmpty) const SizedBox(height: 16),

              // ── Family Health Board ────────────────────────────────
              if (_leaderboard.length > 1) ...[
                GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FAMILY HEALTH BOARD',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 2),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_leaderboard.length, (i) {
                        final entry = _leaderboard[i];
                        final name = entry['profile_name'] ?? 'Unknown';
                        final s = (entry['streak_days'] as num?)?.toInt() ?? 0;
                        final p = (entry['points'] as num?)?.toInt() ?? 0;
                        final isMe = entry['profile_id'] == _activeProfileId;
                        final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '  ';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isMe ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
                          ),
                          child: Row(
                            children: [
                              Text(medal, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (s > 0) ...[
                                Text('🔥 $s', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 12),
                              ],
                              Text(
                                '$p pts',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Milestones ─────────────────────────────────────────
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MILESTONES',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 2),
                    ),
                    const SizedBox(height: 12),
                    _Milestone(days: 1, pts: 10, reached: streak >= 1),
                    _Milestone(days: 3, pts: 100, reached: streak >= 3),
                    _Milestone(days: 7, pts: 300, reached: streak >= 7),
                    _Milestone(days: 14, pts: 700, reached: streak >= 14),
                    _Milestone(days: 30, pts: 1500, reached: streak >= 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _streakMessage(int streak) {
    if (streak == 0) return 'Log a reading today to start your streak!';
    if (streak == 1) return 'Great start! Come back tomorrow.';
    if (streak < 7) return 'Keep going — $streak days and counting!';
    if (streak < 14) return '🔥 One week strong! You\'re building a great habit.';
    if (streak < 30) return '🌟 $streak-day streak! You\'re a health champion.';
    return '🏆 $streak days! You\'re in the top tier.';
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
