import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/health_helpers.dart';
import '../glass_card.dart';

/// Score thresholds for health states.
const int kHealthyThreshold = 70;
const int kCautionThreshold = 40;
const int _trendDeadband = 3;

/// The "Living Heart" wellness-score widget on the home screen.
/// Heart color, pulse speed, face icon, and action text communicate
/// health status at a glance for 50+ users with vision problems.
class HealthScoreRing extends StatefulWidget {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final int? profileId;
  final VoidCallback? onTap;
  final VoidCallback onInfoTap;
  final VoidCallback? onCallDoctor;

  /// If set, shows caregiver-style messages (e.g. "Your Mother is doing great").
  final String? relationship;

  const HealthScoreRing({
    super.key,
    required this.data,
    required this.isLoading,
    required this.profileId,
    required this.onTap,
    required this.onInfoTap,
    this.onCallDoctor,
    this.relationship,
  });

  @override
  State<HealthScoreRing> createState() => _HealthScoreRingState();
}

class _HealthScoreRingState extends State<HealthScoreRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  CurvedAnimation? _curvedAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this);
    _updatePulse();
  }

  @override
  void didUpdateWidget(covariant HealthScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldScore = (oldWidget.data?['score'] as num?)?.toInt() ?? 50;
    final newScore = (widget.data?['score'] as num?)?.toInt() ?? 50;
    final oldTier = _tier(oldScore);
    final newTier = _tier(newScore);
    if (oldTier != newTier) _updatePulse();
  }

  int _tier(int score) {
    if (score >= kHealthyThreshold) return 2;
    if (score >= kCautionThreshold) return 1;
    return 0;
  }

  void _updatePulse() {
    final score = (widget.data?['score'] as num?)?.toInt() ?? 50;
    final Duration duration;
    final double maxScale;

    if (score >= kHealthyThreshold) {
      duration = const Duration(milliseconds: 2000);
      maxScale = 1.03;
    } else if (score >= kCautionThreshold) {
      duration = const Duration(milliseconds: 1200);
      maxScale = 1.05;
    } else {
      duration = const Duration(milliseconds: 800);
      maxScale = 1.08;
    }

    _pulseController.stop();
    _curvedAnimation?.dispose();
    _pulseController.duration = duration;
    _curvedAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: maxScale,
    ).animate(_curvedAnimation!);
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _curvedAnimation?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.isLoading) {
      return GlassCard(
        borderRadius: 32,
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    final score = (widget.data?['score'] as num?)?.toInt() ?? 50;
    final insight = widget.data?['insight'] as String? ?? '';
    final previousScore = (widget.data?['previous_score'] as num?)?.toInt();

    final heartColor = heartColorForScore(score);
    final statusText = _statusText(score, l10n);
    final faceText = _faceText(score, l10n);
    final trendArrow = computeTrendArrow(score, previousScore);

    return GestureDetector(
      onTap: widget.onTap,
      child: GlassCard(
        borderRadius: 32,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Stack(
          children: [
            Column(
              children: [
                // Status text — large, bold, colored
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: heartColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // Heart with score
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: 190,
                    height: 176,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(190, 176),
                          painter: HeartPainter(color: heartColor),
                        ),
                        Positioned(
                          top: 56,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$score',
                                style: const TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Color(0x40000000),
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                              if (trendArrow != null) ...[
                                const SizedBox(width: 2),
                                Text(
                                  trendArrow,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 6,
                                        color: Color(0x30000000),
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Face icon + status text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(36, 36),
                      painter: FacePainter(
                        state: faceStateForScore(score),
                        color: heartColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      faceText,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: heartColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status bar — thick, visible
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 12,
                    child: LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: const Color(0xFFE0E5EA),
                      valueColor: AlwaysStoppedAnimation<Color>(heartColor),
                    ),
                  ),
                ),

                // Insight text — large, no italic, dark
                if (insight.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    insight,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF444444),
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Call doctor button — only on urgent
                if (score < kCautionThreshold) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: widget.onCallDoctor ?? widget.onTap,
                      icon: const Icon(
                        Icons.phone,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: Text(
                        l10n.heartCallDoctor,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: heartColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // Info button
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: widget.onInfoTap,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.question_mark_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(int score, AppLocalizations l10n) {
    final rel = widget.relationship;
    if (rel != null && rel.isNotEmpty) {
      if (score >= kHealthyThreshold) return l10n.caregiverStatusGreat(rel);
      if (score >= kCautionThreshold) return l10n.caregiverStatusCaution(rel);
      return l10n.caregiverStatusUrgent(rel);
    }
    if (score >= kHealthyThreshold) return l10n.heartStatusHealthy;
    if (score >= kCautionThreshold) return l10n.heartStatusCaution;
    return l10n.heartStatusUrgent;
  }

  String _faceText(int score, AppLocalizations l10n) {
    if (score >= kHealthyThreshold) return l10n.heartFaceHealthy;
    if (score >= kCautionThreshold) return l10n.heartFaceCaution;
    return l10n.heartFaceUrgent;
  }
}

// ── Public helpers (used by widget and tests) ───────────────────────────

/// Returns the solid heart color for a given score.
Color heartColorForScore(int score) {
  if (score >= kHealthyThreshold) return const Color(0xFF28A745);
  if (score >= kCautionThreshold) return const Color(0xFFFF9500);
  return const Color(0xFFFF3B30);
}

/// Returns the face state for a given score.
FaceState faceStateForScore(int score) {
  if (score >= kHealthyThreshold) return FaceState.happy;
  if (score >= kCautionThreshold) return FaceState.neutral;
  return FaceState.worried;
}

/// Returns the trend arrow string, or null if no previous score.
String? computeTrendArrow(int score, int? previousScore) {
  if (previousScore == null) return null;
  final diff = score - previousScore;
  if (diff > _trendDeadband) return '↑';
  if (diff < -_trendDeadband) return '↓';
  return '→';
}

// ── Heart Shape Painter ─────────────────────────────────────────────────

class HeartPainter extends CustomPainter {
  final Color color;
  const HeartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.5, h * 0.93);
    path.cubicTo(w * 0.5, h * 0.93, w * 0.08, h * 0.62, w * 0.08, h * 0.36);
    path.cubicTo(w * 0.08, h * 0.19, w * 0.21, h * 0.10, w * 0.33, h * 0.10);
    path.cubicTo(w * 0.42, h * 0.10, w * 0.47, h * 0.17, w * 0.5, h * 0.27);
    path.cubicTo(w * 0.53, h * 0.17, w * 0.58, h * 0.10, w * 0.67, h * 0.10);
    path.cubicTo(w * 0.79, h * 0.10, w * 0.92, h * 0.19, w * 0.92, h * 0.36);
    path.cubicTo(w * 0.92, h * 0.62, w * 0.5, h * 0.93, w * 0.5, h * 0.93);
    path.close();

    canvas.drawPath(path, paint);

    // ECG watermark at ~7% opacity
    final ecgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ecgPath = Path();
    final cy = h * 0.52;
    ecgPath.moveTo(w * 0.15, cy);
    ecgPath.lineTo(w * 0.30, cy);
    ecgPath.lineTo(w * 0.36, cy - h * 0.08);
    ecgPath.lineTo(w * 0.42, cy + h * 0.10);
    ecgPath.lineTo(w * 0.48, cy - h * 0.12);
    ecgPath.lineTo(w * 0.54, cy + h * 0.08);
    ecgPath.lineTo(w * 0.58, cy);
    ecgPath.lineTo(w * 0.70, cy);
    ecgPath.lineTo(w * 0.75, cy - h * 0.03);
    ecgPath.lineTo(w * 0.78, cy + h * 0.03);
    ecgPath.lineTo(w * 0.82, cy);
    ecgPath.lineTo(w * 0.88, cy);

    canvas.drawPath(ecgPath, ecgPaint);
  }

  @override
  bool shouldRepaint(HeartPainter old) => old.color != color;
}

// ── Face Painter ────────────────────────────────────────────────────────

enum FaceState { happy, neutral, worried }

class FacePainter extends CustomPainter {
  final FaceState state;
  final Color color;
  const FacePainter({required this.state, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, circlePaint);

    final eyePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.15),
      2.5,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.3, center.dy - radius * 0.15),
      2.5,
      eyePaint,
    );

    final mouthPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();
    final my = center.dy + radius * 0.25;
    final mx = center.dx;

    switch (state) {
      case FaceState.happy:
        mouthPath.moveTo(mx - radius * 0.35, my - radius * 0.05);
        mouthPath.quadraticBezierTo(
          mx,
          my + radius * 0.35,
          mx + radius * 0.35,
          my - radius * 0.05,
        );
      case FaceState.neutral:
        mouthPath.moveTo(mx - radius * 0.3, my + radius * 0.05);
        mouthPath.lineTo(mx + radius * 0.3, my + radius * 0.05);
      case FaceState.worried:
        mouthPath.moveTo(mx - radius * 0.35, my + radius * 0.15);
        mouthPath.quadraticBezierTo(
          mx,
          my - radius * 0.2,
          mx + radius * 0.35,
          my + radius * 0.15,
        );
    }

    canvas.drawPath(mouthPath, mouthPaint);
  }

  @override
  bool shouldRepaint(FacePainter old) =>
      old.state != state || old.color != color;
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
      (
        emoji: '🟢',
        label: 'Fit & Fine',
        color: AppColors.statusNormal,
        desc:
            'All your readings are within healthy ranges. Keep up the great habits!',
      ),
      (
        emoji: '🟡',
        label: 'Caution',
        color: AppColors.amber,
        desc:
            'One or more readings are slightly elevated. Monitor them daily and stay hydrated.',
      ),
      (
        emoji: '🟠',
        label: 'At Risk',
        color: AppColors.statusElevated,
        desc:
            'Your readings suggest increased risk. Consider lifestyle changes and consult your doctor.',
      ),
      (
        emoji: '🚨',
        label: 'Urgent',
        color: AppColors.statusCritical,
        desc:
            'A critical reading was detected. Please contact your doctor or family member immediately.',
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
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
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 2,
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
                      style: TextStyle(
                        fontSize: 11,
                        color: current.color.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      current.label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: current.color,
                      ),
                    ),
                    if (current.subLabel != null)
                      Text(
                        current.subLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: current.color.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Text(
            'WHAT EACH LEVEL MEANS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ...levels.map(
            (lvl) => Padding(
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: lvl.color,
                          ),
                        ),
                        Text(
                          lvl.desc,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
