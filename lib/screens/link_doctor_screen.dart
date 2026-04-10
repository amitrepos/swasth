import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/doctor_service.dart';
import '../services/storage_service.dart';
import '../widgets/glass_card.dart';

/// Patient-facing screen for sharing readings with a doctor.
///
/// Two ways to pick a doctor:
///   1. **Picker** (preferred) — tap a card from the list of doctors
///      already linked to any of the patient's owned profiles.
///   2. **Code fallback** — for first-time links. Patient types the
///      doctor's Swasth code (e.g. DRRAJ52) and taps Find Doctor.
///
/// Once a doctor is selected (either way), the existing consent
/// tile + confirmation dialog + link POST flow runs unchanged.
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

  // Picker state
  List<Map<String, dynamic>>? _directoryDoctors;
  Set<String> _alreadyLinkedCodes = <String>{};
  bool _isLoadingPicker = true;

  // Code-entry state
  bool _codeEntryExpanded = false;
  bool _isLookingUp = false;
  String? _lookupError;

  // Selection + link state
  Map<String, dynamic>? _selectedDoctor;
  // True if the current _selectedDoctor was picked from the directory
  // list rather than entered via the code field. Used by the code
  // field's onChanged handler so an accidental keystroke doesn't wipe
  // a picker selection.
  bool _selectedFromPicker = false;
  String _consentType = 'in_person_exam';
  bool _isLinking = false;

  int? _activeProfileId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPicker());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _normalizeCode(String raw) =>
      raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

  Future<void> _loadPicker() async {
    setState(() => _isLoadingPicker = true);
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');
      final profileId = await _storageService.getActiveProfileId();

      // Phase 4+: picker is sourced from the platform-wide directory
      // of verified doctors, not just the patient's own prior links.
      // This matches the patient's mental model — "pick Dr. Rajesh by
      // name" — and removes the first-time code memorization.
      final directory = await _doctorService.getDirectory(token);

      // Cross-reference with the current profile's linked doctors so
      // the picker can mark already-linked cards as disabled.
      Set<String> alreadyLinked = <String>{};
      if (profileId != null) {
        try {
          final linked = await _doctorService.getLinkedDoctors(
            token,
            profileId,
          );
          alreadyLinked = linked
              .whereType<Map<String, dynamic>>()
              .map((d) => (d['doctor_code'] as String?) ?? '')
              .where((c) => c.isNotEmpty)
              .toSet();
        } catch (_) {
          // Non-fatal — picker still works without the "already linked" hint.
        }
      }

      if (!mounted) return;
      setState(() {
        _directoryDoctors = directory;
        _alreadyLinkedCodes = alreadyLinked;
        _activeProfileId = profileId;
        _isLoadingPicker = false;
        // If the directory is empty (no verified doctors on the
        // platform yet, e.g. early-pilot day 1), fall back to the
        // code-entry path so the user still has something to do.
        if (directory.isEmpty) _codeEntryExpanded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _directoryDoctors = const [];
        _isLoadingPicker = false;
        _codeEntryExpanded = true;
      });
    }
  }

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

  Future<void> _lookupCode() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLookingUp = true;
      _lookupError = null;
      _selectedDoctor = null;
      _selectedFromPicker = false;
    });
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');
      final doctor = await _doctorService.lookupDoctor(
        token,
        _normalizeCode(_codeController.text),
      );
      if (!mounted) return;
      setState(() {
        _selectedDoctor = doctor;
        _selectedFromPicker = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _lookupError = _mapErrorToMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  void _selectFromPicker(Map<String, dynamic> doctor) {
    final l10n = AppLocalizations.of(context)!;
    final code = (doctor['doctor_code'] as String?) ?? '';
    if (_alreadyLinkedCodes.contains(code)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.linkDoctorAlreadyLinked)));
      return;
    }
    setState(() {
      _selectedDoctor = doctor;
      _selectedFromPicker = true;
      _lookupError = null;
    });
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
    final doctor = _selectedDoctor;
    if (doctor == null) return;

    if (doctor['is_verified'] != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.linkDoctorNotVerifiedHelp)));
      return;
    }

    final profileId =
        _activeProfileId ?? await _storageService.getActiveProfileId();
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
      // Phase 4: the link is now pending doctor acceptance. Show the
      // patient a clearer message so they don't expect immediate access.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.linkDoctorRequestSent(doctor['doctor_name'] as String),
          ),
          backgroundColor: AppColors.statusNormal,
          duration: const Duration(seconds: 4),
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

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.linkDoctorTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
              if (_isLoadingPicker)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if ((_directoryDoctors ?? const []).isNotEmpty) ...[
                  _buildPickerSection(context, l10n),
                  const SizedBox(height: 16),
                  _buildOrDivider(context, l10n),
                  const SizedBox(height: 16),
                ],
                _buildCodeEntrySection(context, l10n),
              ],
              if (_selectedDoctor != null) ...[
                const SizedBox(height: 24),
                _buildDoctorCard(context, _selectedDoctor!),
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
    );
  }

  // ---------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------

  Widget _buildPickerSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final doctors = _directoryDoctors ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.linkDoctorPickerTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.linkDoctorPickerSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...doctors.map((d) => _buildPickerCard(context, l10n, d)),
      ],
    );
  }

  Widget _buildPickerCard(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic> doctor,
  ) {
    final theme = Theme.of(context);
    final name = (doctor['doctor_name'] as String?) ?? '';
    final specialty = doctor['specialty'] as String?;
    final clinic = doctor['clinic_name'] as String?;
    final code = (doctor['doctor_code'] as String?) ?? '';
    final alreadyLinked = _alreadyLinkedCodes.contains(code);
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: alreadyLinked ? 0.55 : 1.0,
        child: GlassCard(
          borderRadius: 16,
          child: ListTile(
            key: Key('link_doctor_picker_$code'),
            enabled: !alreadyLinked,
            onTap: alreadyLinked ? null : () => _selectFromPicker(doctor),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: Text(
                initial,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (specialty != null && specialty.isNotEmpty) Text(specialty),
                if (clinic != null && clinic.isNotEmpty)
                  Text(
                    clinic,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (alreadyLinked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.linkDoctorAlreadyLinkedBadge,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.statusNormal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: alreadyLinked
                ? const Icon(Icons.check_circle, color: AppColors.statusNormal)
                : const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildOrDivider(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            l10n.linkDoctorOr,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildCodeEntrySection(BuildContext context, AppLocalizations l10n) {
    if (!_codeEntryExpanded) {
      return OutlinedButton.icon(
        key: const Key('link_doctor_expand_code_button'),
        onPressed: () => setState(() => _codeEntryExpanded = true),
        icon: const Icon(Icons.keyboard_alt_outlined),
        label: Text(l10n.linkDoctorEnterNewCode),
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            onChanged: (_) {
              // Clear the selection only if it came from a code lookup,
              // not a picker tap. Otherwise a stray keystroke would
              // wipe a valid picker selection.
              if (_selectedDoctor != null && !_selectedFromPicker) {
                setState(() {
                  _selectedDoctor = null;
                  _lookupError = null;
                });
              } else if (_lookupError != null) {
                setState(() => _lookupError = null);
              }
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const Key('link_doctor_lookup_button'),
            onPressed: _isLookingUp ? null : _lookupCode,
            icon: _isLookingUp
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(l10n.linkDoctorLookupButton),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, Map<String, dynamic> doctor) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isVerified = doctor['is_verified'] == true;
    final specialty = doctor['specialty'] as String?;
    final clinic = doctor['clinic_name'] as String?;
    final doctorName = (doctor['doctor_name'] as String?) ?? '';
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
