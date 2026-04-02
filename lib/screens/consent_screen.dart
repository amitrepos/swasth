import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';

/// Privacy consent screen shown after registration form.
/// User must scroll to bottom before "Accept" is enabled.
/// On accept, calls [onAccept] callback with consent data,
/// then navigates to LoginScreen.
class ConsentScreen extends StatefulWidget {
  /// Called when user accepts — parent should include consent fields
  /// in the registration payload and call the register API.
  final Future<void> Function({
    required String appVersion,
    required String language,
    required bool aiConsent,
  }) onAccept;

  const ConsentScreen({super.key, required this.onAccept});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // If content fits the screen without scrolling, enable Accept immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkContentFits());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkContentFits() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent <= 50) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToBottom) {
        setState(() => _hasScrolledToBottom = true);
      }
    }
  }

  Future<void> _accept() async {
    setState(() => _isSubmitting = true);
    final locale = Localizations.localeOf(context).languageCode;

    try {
      await widget.onAccept(
        appVersion: '1.0.0',
        language: locale,
        aiConsent: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.registerSuccessful),
          backgroundColor: AppColors.statusNormal,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.statusCritical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _decline() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.consentDeclineTitle),
        content: Text(l10n.consentDeclineMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusCritical,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.consentDeclineConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.consentTitle),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield, color: AppColors.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.consentSubject,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    l10n.consentIntro,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _ConsentSection(
                    icon: Icons.storage,
                    title: l10n.consentDataCollectionTitle,
                    body: l10n.consentDataCollection,
                  ),
                  const SizedBox(height: 16),

                  _ConsentSection(
                    icon: Icons.family_restroom,
                    title: l10n.consentFamilySharingTitle,
                    body: l10n.consentFamilySharing,
                  ),
                  const SizedBox(height: 16),

                  _ConsentSection(
                    icon: Icons.health_and_safety,
                    title: l10n.consentPurposeTitle,
                    body: l10n.consentPurpose,
                  ),
                  const SizedBox(height: 16),

                  _ConsentSection(
                    icon: Icons.gavel,
                    title: l10n.consentRightsTitle,
                    body: l10n.consentRights,
                  ),
                  const SizedBox(height: 16),

                  _ConsentSection(
                    icon: Icons.smart_toy,
                    title: l10n.consentAiTitle,
                    body: l10n.consentAiBody,
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(l10n.privacyPolicy),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Scroll hint
                  if (!_hasScrolledToBottom)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.keyboard_arrow_down,
                              color: AppColors.textSecondary, size: 28),
                          Text(
                            l10n.consentScrollToAccept,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.separator, width: 0.5),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _hasScrolledToBottom && !_isSubmitting
                        ? _accept
                        : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.consentAccept),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSubmitting ? null : _decline,
                  child: Text(
                    l10n.consentDecline,
                    style: const TextStyle(color: AppColors.textSecondary),
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

class _ConsentSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ConsentSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
