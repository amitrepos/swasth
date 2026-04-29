import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// AI health insight card — collapsed to 2 lines by default, expandable on tap.
class AiInsightCard extends StatefulWidget {
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
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            l10n.aiInsightSection.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedBuilder(
                            animation: widget.pulseAnimation,
                            builder: (context, _) => Opacity(
                              opacity: widget.pulseAnimation.value,
                              child: const CircleAvatar(
                                radius: 3,
                                backgroundColor: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onSaveToggle,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isSaved ? Icons.star : Icons.star_border,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<String>(
                  future: widget.insightFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 30,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      );
                    }
                    final text = snap.data ?? '';
                    final displayText = text.isNotEmpty
                        ? text
                        : 'Log daily readings for the best health insights.';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                        ),
                        if (!_expanded && displayText.length > 80)
                          GestureDetector(
                            onTap: () => setState(() => _expanded = true),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${l10n.readMore} ›',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        if (_expanded)
                          GestureDetector(
                            onTap: () => setState(() => _expanded = false),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${l10n.cancel} ›',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)!.nmcDisclaimer,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Left accent bar
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
