import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tosTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(l10n.tosAcceptanceTitle),
            _body(l10n.tosAcceptance),
            const SizedBox(height: 20),
            _heading(l10n.tosServiceTitle),
            _body(l10n.tosService),
            const SizedBox(height: 20),
            _heading(l10n.tosAiTitle),
            _body(l10n.tosAi),
            const SizedBox(height: 20),
            _heading(l10n.tosDoctorTitle),
            _body(l10n.tosDoctor),
            const SizedBox(height: 20),
            _heading(l10n.tosLiabilityTitle),
            _body(l10n.tosLiability),
            const SizedBox(height: 20),
            _heading(l10n.tosTerminationTitle),
            _body(l10n.tosTermination),
            const SizedBox(height: 20),
            _heading(l10n.tosGoverningTitle),
            _body(l10n.tosGoverning),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
  );

  Widget _body(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      height: 1.6,
      color: AppColors.textSecondary,
    ),
  );
}
