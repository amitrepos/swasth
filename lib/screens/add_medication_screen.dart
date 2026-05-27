// Modal bottom-sheet for logging medicines (NUO-127).
//
// Per-user feedback: medication-add is a POPUP (modal bottom-sheet), not a
// full page like BP/glucose. Patients (Sunita persona) typically take 3–5
// meds at one sitting, so the sheet supports CHAINED logging: after each
// successful save, the form clears and a green banner shows the last-saved
// name. The user keeps logging until they tap "Done", which pops the sheet
// and the parent list refreshes.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medication_model.dart';
import '../services/api_exception.dart';
import '../services/error_mapper.dart';
import '../services/medication_service.dart';
import '../services/storage_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Show the medication-add sheet. Resolves to `true` if at least one medicine
/// was successfully logged (so the caller can refresh the list), `false` /
/// `null` otherwise.
Future<bool?> showAddMedicationSheet(
  BuildContext context, {
  required int profileId,
  Medication? initialMedication,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    builder: (_) => AddMedicationSheet(
      profileId: profileId,
      initialMedication: initialMedication,
    ),
  );
}

/// Content widget for the medication-add modal. Exposed (not private) so
/// widget tests can mount it directly without going through showModalBottomSheet.
class AddMedicationSheet extends StatefulWidget {
  final int profileId;
  final Medication? initialMedication;
  const AddMedicationSheet({
    super.key,
    required this.profileId,
    this.initialMedication,
  });

  @override
  State<AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<AddMedicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _doseCtl = TextEditingController();
  final _freqCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  final _nameFocus = FocusNode();
  DateTime _takenAt = DateTime.now();
  bool _saving = false;
  int _savedCount = 0;
  String? _lastSavedName;

  bool get _isEditMode => widget.initialMedication != null;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMedication;
    if (m != null) {
      _nameCtl.text = m.name;
      _doseCtl.text = m.dose ?? '';
      _freqCtl.text = m.frequency ?? '';
      _notesCtl.text = m.notes ?? '';
      _takenAt = m.takenAt.toLocal();
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _doseCtl.dispose();
    _freqCtl.dispose();
    _notesCtl.dispose();
    _nameFocus.dispose();
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
    setState(
      () => _takenAt = DateTime(d.year, d.month, d.day, t.hour, t.minute),
    );
  }

  void _resetForm() {
    _nameCtl.clear();
    _doseCtl.clear();
    _freqCtl.clear();
    _notesCtl.clear();
    _formKey.currentState?.reset();
    setState(() {
      _takenAt = DateTime.now();
      _saving = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Not authenticated');
      final savedName = _nameCtl.text.trim();

      if (_isEditMode) {
        await MedicationService().updateMedication(
          widget.initialMedication!.id,
          MedicationUpdate(
            name: savedName,
            dose: _doseCtl.text.trim(),
            frequency: _freqCtl.text.trim(),
            takenAt: _takenAt,
            notes: _notesCtl.text.trim(),
          ),
          token,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      } else {
        await MedicationService().saveMedication(
          MedicationCreate(
            profileId: widget.profileId,
            name: savedName,
            dose: _doseCtl.text.trim().isEmpty ? null : _doseCtl.text.trim(),
            frequency:
                _freqCtl.text.trim().isEmpty ? null : _freqCtl.text.trim(),
            takenAt: _takenAt,
            notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
          ),
          token,
        );
        if (!mounted) return;
        setState(() {
          _savedCount += 1;
          _lastSavedName = savedName;
        });
        _resetForm();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMapper.userMessage(AppLocalizations.of(context)!, e),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  void _done() {
    Navigator.pop(context, _savedCount > 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mq = MediaQuery.of(context);
    // Sheet covers ~92% of viewport so chained logging has comfortable space.
    final maxHeight = mq.size.height * 0.92;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header with title + close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditMode
                          ? l10n.medicationsEditTitle
                          : l10n.medicationsLogFab,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('medication-close-btn'),
                    icon: const Icon(Icons.close),
                    onPressed: _saving ? null : _done,
                  ),
                ],
              ),
            ),
            if (_lastSavedName != null && !_isEditMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  key: const Key('medication-saved-banner'),
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"$_lastSavedName" saved${_savedCount > 1 ? '  ·  $_savedCount logged' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        key: const Key('medication-name-field'),
                        controller: _nameCtl,
                        focusNode: _nameFocus,
                        decoration: const InputDecoration(
                          labelText: 'Medicine name *',
                          hintText: 'e.g. Metformin',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name required'
                            : null,
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
                          child: Text(
                            DateFormat.yMMMd().add_jm().format(_takenAt),
                          ),
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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const Key('medication-save-btn'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.add, size: 20),
                      label: Text(
                        _isEditMode
                            ? l10n.medicationsSaveChanges
                            : (_savedCount == 0 ? 'Save' : 'Save & add more'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!_isEditMode)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        key: const Key('medication-done-btn'),
                        onPressed: _saving ? null : _done,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          _savedCount > 0
                              ? 'Done ($_savedCount logged)'
                              : 'Done',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
