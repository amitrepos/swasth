import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/doctor_service.dart';
import '../services/storage_service.dart';

/// Patient-facing screen: enter a doctor code, preview the doctor,
/// pick a consent type, and link the active profile to that doctor.
class LinkDoctorScreen extends StatefulWidget {
  const LinkDoctorScreen({super.key});

  @override
  State<LinkDoctorScreen> createState() => _LinkDoctorScreenState();
}

class _LinkDoctorScreenState extends State<LinkDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _doctorService = DoctorService();
  final _storageService = StorageService();

  Map<String, dynamic>? _lookedUpDoctor;
  String _consentType = 'in_person_exam';
  bool _isLookingUp = false;
  bool _isLinking = false;
  String? _lookupError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _normalizeCode(String raw) =>
      raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

  String _mapErrorToMessage(AppLocalizations l10n, Object error) {
    final s = error.toString();
    if (error is TimeoutException ||
        error is SocketException ||
        s.contains('SocketException') ||
        s.contains('TimeoutException')) {
      return l10n.linkDoctorNetworkError;
    }
    if (s.contains('401') || s.contains('Not authenticated')) {
      return l10n.linkDoctorSessionExpired;
    }
    return l10n.linkDoctorLookupFailed;
  }

  Future<void> _lookup() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLookingUp = true;
      _lookupError = null;
      _lookedUpDoctor = null;
    });
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');
      final doctor = await _doctorService.lookupDoctor(
        token,
        _normalizeCode(_codeController.text),
      );
      if (!mounted) return;
      setState(() => _lookedUpDoctor = doctor);
    } catch (e) {
      if (!mounted) return;
      setState(() => _lookupError = _mapErrorToMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  Future<bool> _showConfirmDialog(String doctorName) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.linkDoctorConfirmDialogTitle),
        content: Text(l10n.linkDoctorConfirmDialogBody(doctorName)),
        actions: [
          TextButton(
            key: const Key('link_doctor_confirm_dialog_cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: const Key('link_doctor_confirm_dialog_share'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.linkDoctorConfirmDialogShare),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _link() async {
    final l10n = AppLocalizations.of(context)!;
    final doctor = _lookedUpDoctor;
    if (doctor == null) return;

    // Unverified doctors are also backend-blocked; this is a UI guard so
    // the user sees a clear message instead of an API error.
    if (doctor['is_verified'] != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.linkDoctorNotVerifiedHelp)));
      return;
    }

    final profileId = await _storageService.getActiveProfileId();
    if (profileId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.linkDoctorNoProfile)));
      return;
    }

    if (!mounted) return;
    final confirmed = await _showConfirmDialog(doctor['doctor_name'] as String);
    if (!confirmed || !mounted) return;

    setState(() => _isLinking = true);
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');
      await _doctorService.linkDoctor(
        token,
        profileId,
        doctor['doctor_code'] as String,
        _consentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.linkDoctorSuccess(doctor['doctor_name'] as String),
          ),
          backgroundColor: AppColors.statusNormal,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.statusCritical,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.linkDoctorTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.linkDoctorHeadline,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('link_doctor_code'),
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.linkDoctorCodeLabel,
                    hintText: l10n.linkDoctorCodeHint,
                    helperText: l10n.linkDoctorCodeHelper,
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.medical_services_outlined),
                    errorText: _lookupError,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.linkDoctorCodeEmpty;
                    }
                    if (_normalizeCode(value).length < 4) {
                      return l10n.linkDoctorCodeInvalid;
                    }
                    return null;
                  },
                  onChanged: (value) {
                    // Only clear the card if the typed code actually
                    // differs from the looked-up one — elderly users
                    // often bump keys by accident.
                    final currentCode =
                        _lookedUpDoctor?['doctor_code'] as String?;
                    final typedNormalized = _normalizeCode(value);
                    final cardStale =
                        _lookedUpDoctor != null &&
                        typedNormalized != currentCode;
                    if (cardStale || _lookupError != null) {
                      setState(() {
                        if (cardStale) _lookedUpDoctor = null;
                        _lookupError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('link_doctor_lookup_button'),
                  onPressed: _isLookingUp ? null : _lookup,
                  icon: _isLookingUp
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(l10n.linkDoctorLookupButton),
                ),
                if (_lookedUpDoctor != null) ...[
                  const SizedBox(height: 24),
                  _buildDoctorCard(context, _lookedUpDoctor!),
                  const SizedBox(height: 24),
                  Text(
                    l10n.linkDoctorConsentTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildConsentTile(
                    value: 'in_person_exam',
                    title: l10n.linkDoctorConsentInPerson,
                    subtitle: l10n.linkDoctorConsentInPersonHelp,
                  ),
                  _buildConsentTile(
                    value: 'video_consult',
                    title: l10n.linkDoctorConsentVideo,
                    subtitle: l10n.linkDoctorConsentVideoHelp,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoBox(
                    context,
                    icon: Icons.info_outline,
                    text: l10n.linkDoctorNmcDisclaimer,
                    color: AppColors.statusElevated,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoBox(
                    context,
                    icon: Icons.shield_outlined,
                    text: l10n.linkDoctorRevokeHint,
                    color: AppColors.statusNormal,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('link_doctor_confirm_button'),
                    onPressed: _isLinking ? null : _link,
                    child: _isLinking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.linkDoctorConfirm),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, Map<String, dynamic> doctor) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isVerified = doctor['is_verified'] == true;
    final specialty = doctor['specialty'] as String?;
    final clinic = doctor['clinic_name'] as String?;
    final doctorName = doctor['doctor_name'] as String? ?? '';
    final firstInitial = doctorName.isNotEmpty
        ? doctorName.trim()[0].toUpperCase()
        : '?';

    return Card(
      key: const Key('link_doctor_card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.statusNormal.withOpacity(0.15),
                  child: Text(
                    firstInitial,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.statusNormal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (specialty != null && specialty.isNotEmpty)
                        Text(specialty, style: theme.textTheme.bodyMedium),
                      if (clinic != null && clinic.isNotEmpty)
                        Text(
                          clinic,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Verification status — icon carries the color; text stays in
            // theme-default color to preserve contrast (WCAG AA).
            Row(
              children: [
                Icon(
                  isVerified ? Icons.verified : Icons.schedule_outlined,
                  size: 20,
                  color: isVerified
                      ? AppColors.statusNormal
                      : AppColors.statusElevated,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVerified
                        ? l10n.linkDoctorVerified
                        : l10n.linkDoctorNotVerified,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (!isVerified) ...[
              const SizedBox(height: 6),
              Text(
                l10n.linkDoctorNotVerifiedHelp,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentTile({
    required String value,
    required String title,
    required String subtitle,
  }) {
    return RadioListTile<String>(
      key: Key('link_doctor_consent_$value'),
      value: value,
      groupValue: _consentType,
      onChanged: (v) => setState(() => _consentType = v ?? _consentType),
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
  }
}
