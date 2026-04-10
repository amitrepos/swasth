import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

/// Care Circle card showing family members connected to a profile.
///
/// Displays avatars with role badges, relationship labels,
/// and quick Call/WhatsApp contact options.
class CareCircleCard extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final bool isLoading;

  /// Email of the current user — filtered out of the display.
  final String? currentUserEmail;

  const CareCircleCard({
    super.key,
    required this.members,
    this.isLoading = false,
    this.currentUserEmail,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Filter out the current user
    final visible = currentUserEmail != null
        ? members
              .where(
                (m) =>
                    (m['email'] as String?)?.toLowerCase() !=
                    currentUserEmail!.toLowerCase(),
              )
              .toList()
        : members;

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.careCircleTitle.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No family members linked',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            Row(
              children: visible
                  .map((m) => Expanded(child: _MemberChip(member: m)))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final Map<String, dynamic> member;

  const _MemberChip({required this.member});

  @override
  Widget build(BuildContext context) {
    final name = member['full_name'] as String? ?? 'Unknown';
    final relationship = member['relationship'] as String? ?? '';
    final accessLevel = member['access_level'] as String? ?? 'viewer';
    final phone = member['phone_number'] as String?;
    final email = member['email'] as String?;
    final initials = _initials(name);
    final roleColor = _roleColor(accessLevel);

    return GestureDetector(
      onTap: () =>
          _showContactOptions(context, name, email, phone, accessLevel),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with role ring
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: roleColor, width: 2),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Name
            Text(
              name.split(' ').first,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            // Relationship
            if (relationship.isNotEmpty)
              Text(
                _capitalize(relationship),
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
              ),
            // Role badge
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _roleLabel(accessLevel),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: roleColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String level) {
    switch (level) {
      case 'owner':
        return AppColors.primary;
      case 'editor':
        return AppColors.statusNormal;
      default:
        return AppColors.textSecondary;
    }
  }

  String _roleLabel(String level) {
    switch (level) {
      case 'owner':
        return 'OWNER';
      case 'editor':
        return 'EDITOR';
      default:
        return 'VIEWER';
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _showContactOptions(
    BuildContext ctx,
    String name,
    String? email,
    String? phone,
    String accessLevel,
  ) {
    final hasPhone = phone != null && phone.isNotEmpty;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_capitalize(accessLevel)} · ${email ?? ''}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (hasPhone) ...[
              ListTile(
                leading: const Icon(Icons.phone, color: AppColors.primary),
                title: const Text('Call'),
                subtitle: Text(phone),
                onTap: () {
                  Navigator.pop(ctx);
                  final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
                  launchUrl(Uri.parse('tel:$cleaned'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: AppColors.statusNormal),
                title: const Text('WhatsApp'),
                onTap: () {
                  Navigator.pop(ctx);
                  final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
                  final digits = cleaned.startsWith('+')
                      ? cleaned.substring(1)
                      : cleaned;
                  launchUrl(
                    Uri.parse('https://wa.me/$digits'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
            if (email != null && email.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Send Email'),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('mailto:$email'));
                },
              ),
          ],
        ),
      ),
    );
  }
}
