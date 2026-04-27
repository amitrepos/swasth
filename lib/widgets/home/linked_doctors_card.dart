import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// Dashboard card showing the patient's primary linked doctor (sourced
/// from `DoctorPatientLink`, not the legacy `profile.doctor_name` field).
///
/// "Primary" today is a convention, not a schema field: the most-recently
/// linked `status='active'` row wins. Additional active links are
/// surfaced as caregivers in a separate card (future work).
///
/// Always renders something — when no doctor is linked, shows an empty
/// state with a "Link a doctor" CTA so the dashboard never silently
/// drops the section.
///
/// Accessibility: section header 12sp, name 16sp, specialty 13sp, status
/// 13sp. CTA tap target is ≥48dp tall with InkWell ripple feedback. Status
/// uses an icon + text + color so color-blind users have a non-color cue.
class LinkedDoctorsCard extends StatelessWidget {
  /// Decoded list returned by `DoctorService.getLinkedDoctors`. Each
  /// entry is a `Map<String, dynamic>` with keys: `doctor_name`,
  /// `specialty`, `doctor_code`, `is_verified`, `linked_since`, `status`.
  final List<Map<String, dynamic>> linkedDoctors;

  /// Tapped when the empty-state CTA is pressed.
  final VoidCallback? onLinkDoctorTap;

  const LinkedDoctorsCard({
    super.key,
    required this.linkedDoctors,
    this.onLinkDoctorTap,
  });

  /// Picks the doctor to render as the primary card.
  ///
  /// Rule: prefer `status='active'`, most recently linked first. If none
  /// are active, fall back to the most recent `pending_doctor_accept`
  /// so the patient sees their pending request. If neither exists, show
  /// the most recent `revoked` so the patient sees their declined request.
  Map<String, dynamic>? _pickPrimary() {
    if (linkedDoctors.isEmpty) return null;
    
    // Prefer active links
    final actives = linkedDoctors.where((d) => d['status'] == 'active').toList()
      ..sort((a, b) {
        final aTs = (a['linked_since'] ?? '') as String;
        final bTs = (b['linked_since'] ?? '') as String;
        return bTs.compareTo(aTs);
      });
    if (actives.isNotEmpty) return actives.first;
    
    // Then pending requests
    final pending =
        linkedDoctors
            .where((d) => d['status'] == 'pending_doctor_accept')
            .toList()
          ..sort((a, b) {
            final aTs = (a['linked_since'] ?? '') as String;
            final bTs = (b['linked_since'] ?? '') as String;
            return bTs.compareTo(aTs);
          });
    if (pending.isNotEmpty) return pending.first;
    
    // Finally, show recently revoked/declined
    final revoked =
        linkedDoctors
            .where((d) => d['status'] == 'revoked')
            .toList()
          ..sort((a, b) {
            final aTs = (a['revoked_at'] ?? '') as String;
            final bTs = (b['revoked_at'] ?? '') as String;
            return bTs.compareTo(aTs);
          });
    return revoked.isNotEmpty ? revoked.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = _pickPrimary();

    if (primary == null) {
      return _EmptyState(l10n: l10n, onTap: onLinkDoctorTap);
    }

    final isPending = primary['status'] == 'pending_doctor_accept';
    final isRevoked = primary['status'] == 'revoked';
    final name = (primary['doctor_name'] as String?) ?? '';
    final specialty = (primary['specialty'] as String?) ?? '';
    final revokeReason = primary['revoke_reason'] as String?;

    // Determine status indicators
    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (isRevoked) {
      statusIcon = Icons.cancel;
      statusColor = AppColors.statusCritical;
      statusText = l10n.doctorDeclinedBadge;
    } else if (isPending) {
      statusIcon = Icons.schedule;
      statusColor = AppColors.warning;
      statusText = l10n.doctorPendingAcceptBadge;
    } else {
      statusIcon = Icons.check_circle;
      statusColor = AppColors.success;
      statusText = l10n.physicianConnected;
    }

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                isRevoked ? '❌' : '👩‍⚕️',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.primaryPhysicianSection.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  key: const Key('linked_doctor_name'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (specialty.isNotEmpty)
                  Text(
                    specialty,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      statusIcon,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                // Show decline reason if available
                if (isRevoked && revokeReason != null && revokeReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Reason: $revokeReason',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  const _EmptyState({required this.l10n, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('👩‍⚕️', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.primaryPhysicianSection.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.noDoctorLinked,
                  key: const Key('linked_doctor_empty'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // 48dp tap target with Material ripple. Padding gives effective
          // height ≥48dp regardless of font scale.
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('link_doctor_cta'),
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Center(
                    child: Text(
                      l10n.linkADoctorCta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
