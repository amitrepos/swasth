import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/health_helpers.dart';
import '../glass_card.dart';

/// The large wellness-score donut ring card on the home screen.
class HealthScoreRing extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final int? profileId;
  final VoidCallback? onTap;
  final VoidCallback onInfoTap;

  const HealthScoreRing({
    super.key,
    required this.data,
    required this.isLoading,
    required this.profileId,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
    final lastLogged = formatLastLogged(data?['last_logged'] as String?);

    final arcColor = scoreArcColor(score);

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        borderRadius: 32,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Stack(
          children: [
            Column(
              children: [
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
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onInfoTap,
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
}

// ── Score Ring CustomPainter ─────────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double score; // 0-100
  final Color arcColor;

  const _ScoreRingPainter({required this.score, required this.arcColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * (score / 100);

    final bgPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
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

/// Shows the wellness status explanation bottom sheet.
void showStatusInfoSheet(
  BuildContext context,
  StatusFlagData current,
  AppLocalizations l10n,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatusInfoSheet(current: current),
  );
}

/// Bottom sheet explaining each wellness status level.
class StatusInfoSheet extends StatelessWidget {
  final StatusFlagData current;
  const StatusInfoSheet({super.key, required this.current});

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
