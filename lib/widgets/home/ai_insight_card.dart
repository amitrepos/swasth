import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// AI health insight card with pulsing dot and star-save toggle.
class AiInsightCard extends StatelessWidget {
  final Future<String>? insightFuture;
  final Animation<double> pulseAnimation;
  final bool isSaved;
  final VoidCallback onSaveToggle;

  const AiInsightCard({
    super.key,
    required this.insightFuture,
    required this.pulseAnimation,
    required this.isSaved,
    required this.onSaveToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.aiInsightSection.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedBuilder(
                            animation: pulseAnimation,
                            builder: (context, _) => Opacity(
                              opacity: pulseAnimation.value,
                              child: const CircleAvatar(
                                radius: 3,
                                backgroundColor: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Based on your last 7 days of readings',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<String>(
                        future: insightFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 40,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                            );
                          }
                          final text = snap.data ?? '';
                          return Text(
                            text.isNotEmpty ? '"$text"' : '"Log daily readings for the best health insights."',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onSaveToggle,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Icon(
                      isSaved ? Icons.star : Icons.star_border,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 4,
              child: ColoredBox(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
