// Medications screen (NUO-127): patient logs medicines they've taken,
// which are then surfaced to their doctor in the weekly report and
// patient summary endpoint.
//
// Intentionally minimal — name + dose + when. No prescription tracking,
// no reminder scheduling. Those land in a follow-up if user demand exists.
//
// Add UX (post-NUO-127): tapping the FAB opens a full-page AddMedicationScreen
// (Navigator.push) matching the BP/glucose add pattern. That screen supports
// chained logging so users can log multiple meds in one sitting before
// returning here. See add_medication_screen.dart.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medication_model.dart';
import '../services/api_exception.dart';
import '../services/region_service.dart';
import '../l10n/app_localizations.dart';
import '../services/error_mapper.dart';
import '../services/medication_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'add_medication_screen.dart';

class MedicationsScreen extends StatefulWidget {
  final int profileId;
  const MedicationsScreen({super.key, required this.profileId});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final MedicationService _service = MedicationService();
  bool _isLoading = true;
  bool _canEdit = true;
  bool _canWriteRegion = true; // NUO-135: false when caller is outside India
  List<Medication> _meds = [];

  @override
  void initState() {
    super.initState();
    _loadAccessLevel();
    _loadRegion();
    _load();
  }

  Future<void> _loadRegion() async {
    final r = await RegionService.getRegion();
    if (mounted) setState(() => _canWriteRegion = r.writeAllowed);
  }

  @override
  void didUpdateWidget(MedicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _loadAccessLevel();
      _load();
    }
  }

  Future<void> _loadAccessLevel() async {
    final level = await StorageService().getActiveProfileAccessLevel();
    if (mounted) setState(() => _canEdit = level != 'viewer');
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Not authenticated');
      final list = await _service.getMedications(
        widget.profileId,
        token,
        days: 30,
      );
      if (!mounted) return;
      setState(() {
        _meds = list;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMapper.userMessage(AppLocalizations.of(context)!, e),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddScreen() async {
    final saved = await showAddMedicationSheet(
      context,
      profileId: widget.profileId,
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Medication med) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete medication entry?'),
        content: Text(
          'Remove "${med.name}" log from ${DateFormat.yMMMd().add_jm().format(med.takenAt.toLocal())}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final token = await StorageService().getToken();
      if (token == null) return;
      await _service.deleteMedication(med.id, token);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMapper.userMessage(AppLocalizations.of(context)!, e),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicines I took'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: (_canEdit && _canWriteRegion)
          ? FloatingActionButton.extended(
              key: const Key('medications-add-fab'),
              onPressed: _openAddScreen,
              icon: const Icon(Icons.add),
              label: const Text('Log medicine'),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meds.isEmpty
          ? _EmptyState(
              canEdit: (_canEdit && _canWriteRegion),
              onAdd: _openAddScreen,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: _meds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = _meds[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.medication, color: AppColors.primary),
                      ),
                      title: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.dose != null) Text('Dose: ${m.dose}'),
                          if (m.frequency != null)
                            Text('Frequency: ${m.frequency}'),
                          Text(
                            DateFormat.yMMMd().add_jm().format(
                              m.takenAt.toLocal(),
                            ),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                          if (m.notes != null && m.notes!.isNotEmpty)
                            Text(
                              'Notes: ${m.notes}',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      trailing: (_canEdit && _canWriteRegion)
                          ? IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _confirmDelete(m),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onAdd;
  const _EmptyState({required this.canEdit, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No medicines logged yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Log medicines you have taken so your doctor can see them in your next report.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          if (canEdit) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Log first medicine'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
