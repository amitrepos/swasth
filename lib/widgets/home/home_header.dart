import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/health_helpers.dart' as helpers;
import '../glass_card.dart';

/// Top header bar: greeting, profile switcher, avatar menu, and pills row.
class HomeHeader extends StatelessWidget {
  final String activeProfileName;
  final int? activeProfileId;
  final int streak;
  final int pts;
  final VoidCallback onSwitchProfile;
  final VoidCallback onViewProfile;
  final VoidCallback onShareProfile;
  final VoidCallback onLanguageTap;
  final VoidCallback onLogout;

  const HomeHeader({
    super.key,
    required this.activeProfileName,
    required this.activeProfileId,
    required this.streak,
    required this.pts,
    required this.onSwitchProfile,
    required this.onViewProfile,
    required this.onShareProfile,
    required this.onLanguageTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? l10n.goodMorning
        : hour >= 12 && hour < 17
            ? l10n.goodAfternoon
            : hour >= 17 && hour < 22
                ? l10n.goodEvening
                : l10n.hello;

    final hasProfile = activeProfileId != null;
    final profileDisplayName = activeProfileName == 'Health'
        ? 'My Profile'
        : activeProfileName;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SWASTH',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // Profile name shown in shell header bar
                ],
              ),
            ),
            // Icons moved to shell header bar
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PillButton(
                icon: '🇮🇳',
                label: 'ENGLISH',
                onTap: onLanguageTap,
              ),
              Container(width: 1, height: 24, color: AppColors.separator),
              _PillButton(
                icon: '🔥',
                label: streak > 0 ? '$streak DAYS' : 'STREAK',
                onTap: () {},
              ),
              Container(width: 1, height: 24, color: AppColors.separator),
              _PillButton(
                icon: '🏆',
                label: pts > 0 ? '${helpers.fmtPoints(pts)} PTS' : 'POINTS',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, size: 22, color: onTap != null ? color : AppColors.separator),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
