import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/health_helpers.dart';
import '../glass_card.dart';

/// The "Living Heart" wellness-score widget on the home screen.
/// Replaces the old donut ring with a heart shape whose color, pulse speed,
/// face icon, and action text communicate health status at a glance.
class HealthScoreRing extends StatefulWidget {
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
  State<HealthScoreRing> createState() => _HealthScoreRingState();
}

class _HealthScoreRingState extends State<HealthScoreRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
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
    _updatePulse();
  }

  void _updatePulse() {
    final score = (widget.data?['score'] as num?)?.toInt() ?? 50;
    final Duration duration;
    final double maxScale;

    if (score >= 70) {
      duration = const Duration(milliseconds: 2000);
      maxScale = 1.03;
    } else if (score >= 40) {
      duration = const Duration(milliseconds: 1200);
      maxScale = 1.05;
    } else {
      duration = const Duration(milliseconds: 800);
      maxScale = 1.08;
    }

    _pulseController.stop();
    _pulseController.duration = duration;
    _pulseAnimation = Tween<double>(begin: 1.0, end: maxScale).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
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

    final heartColor = _heartColor(score);
    final statusText = _statusText(score, l10n);
    final hindiText = _hindiStatusText(score);
    final trendArrow = _trendArrow(score, previousScore);

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
                        // Heart shape
                        CustomPaint(
                          size: const Size(190, 176),
                          painter: _HeartPainter(color: heartColor),
                        ),
                        // Score + trend arrow
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

                // Face icon + Hindi status text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Custom SVG-style face
                    CustomPaint(
                      size: const Size(36, 36),
                      painter: _FacePainter(
                        state: score >= 70
                            ? _FaceState.happy
                            : score >= 40
                                ? _FaceState.neutral
                                : _FaceState.worried,
                        color: heartColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      hindiText,
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
                if (score < 40) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: widget.onTap,
                      icon: const Text('📞', style: TextStyle(fontSize: 20)),
                      label: Text(
                        l10n.localeName == 'hi'
                            ? 'Doctor se baat karein'
                            : 'Call your doctor now',
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
                  child: const Icon(Icons.question_mark_rounded,
                      size: 14, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Solid heart colors — darkened for sunlight readability on budget phones.
  Color _heartColor(int score) {
    if (score >= 70) return const Color(0xFF28A745); // darkened green
    if (score >= 40) return const Color(0xFFFF9500); // solid orange
    return const Color(0xFFFF3B30); // solid red
  }

  String _statusText(int score, AppLocalizations l10n) {
    if (score >= 70) return l10n.localeName == 'hi' ? 'बहुत अच्छा!' : "You're doing great";
    if (score >= 40) return l10n.localeName == 'hi' ? 'ध्यान दें' : 'Monitor closely today';
    return l10n.localeName == 'hi' ? 'डॉक्टर से बात करें' : 'Call your doctor today';
  }

  String _hindiStatusText(int score) {
    if (score >= 70) return 'Sab theek hai';
    if (score >= 40) return 'Aaj dhyan rakhein';
    return 'Aaj doctor se baat karein';
  }

  String? _trendArrow(int score, int? previousScore) {
    if (previousScore == null) return null;
    final diff = score - previousScore;
    if (diff > 3) return '↑';
    if (diff < -3) return '↓';
    return '→';
  }
}

// ── Heart Shape Painter ─────────────────────────────────────────────────

class _HeartPainter extends CustomPainter {
  final Color color;
  const _HeartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Heart shape — proportional to widget size
    path.moveTo(w * 0.5, h * 0.93);
    path.cubicTo(w * 0.5, h * 0.93, w * 0.08, h * 0.62, w * 0.08, h * 0.36);
    path.cubicTo(w * 0.08, h * 0.19, w * 0.21, h * 0.10, w * 0.33, h * 0.10);
    path.cubicTo(w * 0.42, h * 0.10, w * 0.47, h * 0.17, w * 0.5, h * 0.27);
    path.cubicTo(w * 0.53, h * 0.17, w * 0.58, h * 0.10, w * 0.67, h * 0.10);
    path.cubicTo(w * 0.79, h * 0.10, w * 0.92, h * 0.19, w * 0.92, h * 0.36);
    path.cubicTo(w * 0.92, h * 0.62, w * 0.5, h * 0.93, w * 0.5, h * 0.93);
    path.close();

    canvas.drawPath(path, paint);

    // Subtle ECG watermark at ~7% opacity — invisible to low-vision,
    // medical feel for doctors and younger family members
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
  bool shouldRepaint(_HeartPainter old) => old.color != color;
}

// ── Face Painter (replaces emoji for cross-device consistency) ───────────

enum _FaceState { happy, neutral, worried }

class _FacePainter extends CustomPainter {
  final _FaceState state;
  final Color color;
  const _FacePainter({required this.state, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Circle outline
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, circlePaint);

    // Eyes
    final eyePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(center.dx - radius * 0.3, center.dy - radius * 0.15), 2.5, eyePaint);
    canvas.drawCircle(
        Offset(center.dx + radius * 0.3, center.dy - radius * 0.15), 2.5, eyePaint);

    // Mouth
    final mouthPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();
    final my = center.dy + radius * 0.25;
    final mx = center.dx;

    switch (state) {
      case _FaceState.happy:
        mouthPath.moveTo(mx - radius * 0.35, my - radius * 0.05);
        mouthPath.quadraticBezierTo(mx, my + radius * 0.35, mx + radius * 0.35, my - radius * 0.05);
      case _FaceState.neutral:
        mouthPath.moveTo(mx - radius * 0.3, my + radius * 0.05);
        mouthPath.lineTo(mx + radius * 0.3, my + radius * 0.05);
      case _FaceState.worried:
        mouthPath.moveTo(mx - radius * 0.35, my + radius * 0.15);
        mouthPath.quadraticBezierTo(mx, my - radius * 0.2, mx + radius * 0.35, my + radius * 0.15);
    }

    canvas.drawPath(mouthPath, mouthPaint);
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.state != state || old.color != color;
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
