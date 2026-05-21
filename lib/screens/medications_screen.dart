// Medications screen (NUO-127): patient logs medicines they've taken,
// which are then surfaced to their doctor in the weekly report and
// patient summary endpoint.
//
// Intentionally minimal — name + dose + when. No prescription tracking,
// no reminder scheduling. Those land in a follow-up if user demand exists.
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
      final list = await _service.getMedications(widget.profileId, token, days: 30);
      if (!mounted) return;
      setState(() {
        _meds = list;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMapper.userMessage(AppLocalizations.of(context)!, e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMedicationSheet(profileId: widget.profileId),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Medication med) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete medication entry?'),
        content: Text('Remove "${med.name}" log from ${DateFormat.yMMMd().add_jm().format(med.takenAt.toLocal())}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
        SnackBar(content: Text(ErrorMapper.userMessage(AppLocalizations.of(context)!, e))),
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
              onPressed: _openAddSheet,
              icon: const Icon(Icons.add),
              label: const Text('Log medicine'),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meds.isEmpty
              ? _EmptyState(canEdit: (_canEdit && _canWriteRegion), onAdd: _openAddSheet)
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
                              if (m.frequency != null) Text('Frequency: ${m.frequency}'),
                              Text(
                                DateFormat.yMMMd().add_jm().format(m.takenAt.toLocal()),
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                              if (m.notes != null && m.notes!.isNotEmpty)
                                Text('Notes: ${m.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: (_canEdit && _canWriteRegion)
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
          Icon(Icons.medication_outlined, size: 64, color: Colors.grey.shade400),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddMedicationSheet extends StatefulWidget {
  final int profileId;
  const _AddMedicationSheet({required this.profileId});

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _doseCtl = TextEditingController();
  final _freqCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  DateTime _takenAt = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _doseCtl.dispose();
    _freqCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _takenAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_takenAt),
    );
    if (t == null) return;
    setState(() => _takenAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Not authenticated');
      await MedicationService().saveMedication(
        MedicationCreate(
          profileId: widget.profileId,
          name: _nameCtl.text.trim(),
          dose: _doseCtl.text.trim().isEmpty ? null : _doseCtl.text.trim(),
          frequency: _freqCtl.text.trim().isEmpty ? null : _freqCtl.text.trim(),
          takenAt: _takenAt,
          notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
        ),
        token,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMapper.userMessage(AppLocalizations.of(context)!, e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Log a medicine you took',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('medication-name-field'),
                  controller: _nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Medicine name *',
                    hintText: 'e.g. Metformin',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('medication-dose-field'),
                  controller: _doseCtl,
                  decoration: const InputDecoration(
                    labelText: 'Dose (optional)',
                    hintText: 'e.g. 500 mg, 1 tablet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _freqCtl,
                  decoration: const InputDecoration(
                    labelText: 'Frequency (optional)',
                    hintText: 'e.g. Twice daily after food',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Taken at',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat.yMMMd().add_jm().format(_takenAt)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. Felt nauseous after',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('medication-save-btn'),
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Save'),
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
