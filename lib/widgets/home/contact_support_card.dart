// Web-only "Contact Us" footer card — Help & Support 24/7 via WhatsApp, Phone, Email.
// Gated by `kIsWeb` at the call site (home_screen.dart). Renders nothing on
// Android/iOS, so this file stays platform-safe but never appears in mobile UI.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/support_service.dart';
import '../../theme/app_theme.dart';
import '../glass_card.dart';

class ContactSupportCard extends StatefulWidget {
  const ContactSupportCard({super.key});

  @override
  State<ContactSupportCard> createState() => _ContactSupportCardState();
}

class _ContactSupportCardState extends State<ContactSupportCard> {
  late final Future<SupportContacts> _future;

  @override
  void initState() {
    super.initState();
    _future = SupportService().fetchContacts();
  }

  Future<void> _openEmail(String email) async {
    // mailto: on Flutter web is unreliable — if no protocol handler is
    // registered, Chrome opens a blank tab. Open Gmail compose directly:
    // it works for everyone with a Google account (the majority of our
    // India web visitors) and falls back to a normal compose page for
    // logged-out users.
    //
    // Use Uri.https(...queryParameters) so the email + subject are
    // properly percent-encoded. Hand-rolled string interpolation
    // corrupted "+", "&", and spaces (e.g. support+team@... → broken to=).
    final uri = Uri.https('mail.google.com', '/mail/', {
      'view': 'cm',
      'fs': '1',
      'to': email,
      'su': 'Help & Support - Swasth',
    });
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsApp(String number) async {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openPhone(String number) async {
    // tel: accepts '+' and digits — preserve a leading '+' if present so
    // international dialling works; strip everything else (spaces, dashes).
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Defence-in-depth: if this widget is ever inserted outside a `kIsWeb`
    // gate, render nothing rather than show a web-only section on mobile.
    if (!kIsWeb) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<SupportContacts>(
      future: _future,
      builder: (context, snap) {
        final contacts = snap.data;
        // Hide on error — visitors don't need an error toast for this.
        if (snap.hasError) return const SizedBox.shrink();

        return SizedBox(
          width: double.infinity,
          child: GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  l10n.contactUsTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.contactUsSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                if (contacts == null)
                  const SizedBox(
                    height: 36,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (contacts.whatsappNumber != null)
                        _ContactButton(
                          key: const Key('contact_support_whatsapp'),
                          icon: Icons.chat_bubble_outline,
                          label: contacts.whatsappNumber!,
                          color: AppColors.success,
                          onTap: () => _openWhatsApp(contacts.whatsappNumber!),
                        ),
                      if (contacts.phoneNumber != null)
                        _ContactButton(
                          key: const Key('contact_support_phone'),
                          icon: Icons.phone,
                          label: contacts.phoneNumber!,
                          color: AppColors.primary,
                          onTap: () => _openPhone(contacts.phoneNumber!),
                        ),
                      _ContactButton(
                        key: const Key('contact_support_email'),
                        icon: Icons.mail_outline,
                        label: contacts.email,
                        color: AppColors.amber,
                        onTap: () => _openEmail(contacts.email),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactButton extends StatefulWidget {
  const _ContactButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ContactButton> createState() => _ContactButtonState();
}

class _ContactButtonState extends State<_ContactButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.color.withValues(alpha: _hovering ? 0.22 : 0.10);
    final border = widget.color.withValues(alpha: _hovering ? 0.55 : 0.25);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: widget.color),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
