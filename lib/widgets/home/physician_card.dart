import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../models/profile_model.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// Card showing the patient's primary physician with optional WhatsApp link.
class PhysicianCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback? onWhatsAppTap;

  const PhysicianCard({
    super.key,
    required this.profile,
    this.onWhatsAppTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasWhatsApp = profile.doctorWhatsapp?.isNotEmpty == true;

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: Text('👩‍⚕️', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.primaryPhysicianSection.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.doctorName ?? l10n.primaryPhysicianSection,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (profile.doctorSpecialty?.isNotEmpty == true)
                  Text(
                    profile.doctorSpecialty!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                Text(
                  l10n.physicianConnected,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          if (hasWhatsApp)
            GestureDetector(
              onTap: onWhatsAppTap,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Center(child: Text('💬', style: TextStyle(fontSize: 18))),
              ),
            ),
        ],
      ),
    );
  }
}
