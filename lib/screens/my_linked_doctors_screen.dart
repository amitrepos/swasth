import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/doctor_service.dart';
import '../services/storage_service.dart';
import '../widgets/glass_card.dart';

/// Patient-facing list of doctors currently linked to a profile, with a
/// one-tap revoke path (DPDPA § 13 right-to-erasure).
///
/// Data source: `GET /api/doctor/link/{profile_id}`.
/// Revoke: `DELETE /api/doctor/link/{profile_id}?doctor_code=...`.
class MyLinkedDoctorsScreen extends StatefulWidget {
  final int profileId;

  const MyLinkedDoctorsScreen({super.key, required this.profileId});

  @override
  State<MyLinkedDoctorsScreen> createState() => _MyLinkedDoctorsScreenState();
}

class _MyLinkedDoctorsScreenState extends State<MyLinkedDoctorsScreen> {
  final _doctorService = DoctorService();
  final _storageService = StorageService();

  List<Map<String, dynamic>> _linkedDoctors = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _revokingCodes = <String>{};

  // Sentinel value used to signal a network/timeout error from _load;
  // the build method substitutes the localized string so we never need
  // to read AppLocalizations.of(context) before the widget is mounted.
  static const String _kNetworkErrorSentinel = '__network_error__';

  @override
  void initState() {
    super.initState();
    // Defer the load until after the first frame so inherited widgets
    // (including AppLocalizations) are available if we later need them.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');
      final list = await _doctorService.getLinkedDoctors(
        token,
        widget.profileId,
      );
      if (!mounted) return;
      setState(() {
        _linkedDoctors = list.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
        _isLoading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = _kNetworkErrorSentinel;
        _isLoading = false;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _error = _kNetworkErrorSentinel;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<bool> _confirmRevoke(String doctorName) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.linkedDoctorsRevokeDialogTitle(doctorName)),
        content: Text(l10n.linkedDoctorsRevokeDialogBody),
        actions: [
          TextButton(
            key: const Key('revoke_dialog_cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: const Key('revoke_dialog_confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusCritical,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.linkedDoctorsRevokeConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _revoke(Map<String, dynamic> doctor) async {
    final l10n = AppLocalizations.of(context)!;
    final doctorCode = doctor['doctor_code'] as String?;
    final doctorName = (doctor['doctor_name'] as String?) ?? '';
    if (doctorCode == null) return;

    final confirmed = await _confirmRevoke(doctorName);
    if (!confirmed || !mounted) return;

    setState(() => _revokingCodes.add(doctorCode));
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');
      await _doctorService.revokeDoctorLink(
        token,
        widget.profileId,
        doctorCode,
      );
      if (!mounted) return;
      setState(() {
        _linkedDoctors = _linkedDoctors
            .where((d) => d['doctor_code'] != doctorCode)
            .toList(growable: false);
        _revokingCodes.remove(doctorCode);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.linkedDoctorsRevokeSuccess(doctorName)),
          backgroundColor: AppColors.statusNormal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _revokingCodes.remove(doctorCode));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.statusCritical,
        ),
      );
    }
  }

  String _formatLinkedSince(dynamic raw) {
    if (raw == null) return '';
    try {
      final parsed = DateTime.parse(raw.toString()).toLocal();
      return DateFormat.yMMMd().format(parsed);
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.linkedDoctorsTitle)),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(l10n)),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 48),
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.statusCritical,
          ),
          const SizedBox(height: 12),
          Text(
            _error == _kNetworkErrorSentinel
                ? l10n.linkedDoctorsError
                : _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ),
        ],
      );
    }
    if (_linkedDoctors.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 64),
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.linkedDoctorsEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.linkedDoctorsEmptyHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _linkedDoctors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doctor = _linkedDoctors[index];
        return _buildDoctorCard(l10n, doctor);
      },
    );
  }

  Widget _buildDoctorCard(AppLocalizations l10n, Map<String, dynamic> doctor) {
    final theme = Theme.of(context);
    final name = (doctor['doctor_name'] as String?) ?? '';
    final specialty = doctor['specialty'] as String?;
    final code = (doctor['doctor_code'] as String?) ?? '';
    final linkedSince = _formatLinkedSince(doctor['linked_since']);
    final isRevoking = _revokingCodes.contains(code);
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return GlassCard(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: Key('linked_doctor_${code.isEmpty ? name : code}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(
                    initial,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
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
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (specialty != null && specialty.isNotEmpty)
                        Text(specialty, style: theme.textTheme.bodyMedium),
                      if (linkedSince.isNotEmpty)
                        Text(
                          l10n.linkedDoctorsLinkedSince(linkedSince),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('revoke_button_$code'),
                onPressed: isRevoking ? null : () => _revoke(doctor),
                icon: isRevoking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.link_off,
                        color: AppColors.statusCritical,
                      ),
                label: Text(
                  l10n.linkedDoctorsRevoke,
                  style: const TextStyle(color: AppColors.statusCritical),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
