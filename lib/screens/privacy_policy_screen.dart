import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicy)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(l10n.ppDataCollectionTitle),
            _body(l10n.ppDataCollection),
            const SizedBox(height: 20),
            _heading(l10n.ppPurposeTitle),
            _body(l10n.ppPurpose),
            const SizedBox(height: 20),
            _heading(l10n.ppAiTitle),
            _body(l10n.ppAi),
            const SizedBox(height: 20),
            _heading(l10n.ppSharingTitle),
            _body(l10n.ppSharing),
            const SizedBox(height: 20),
            _heading(l10n.ppSecurityTitle),
            _body(l10n.ppSecurity),
            const SizedBox(height: 20),
            _heading(l10n.ppRetentionTitle),
            _body(l10n.ppRetention),
            const SizedBox(height: 20),
            _heading(l10n.ppRightsTitle),
            _body(l10n.ppRights),
            const SizedBox(height: 20),
            _heading(l10n.ppContactTitle),
            _body(l10n.ppContact),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      );

  Widget _body(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14, height: 1.6, color: AppColors.textSecondary));
}
