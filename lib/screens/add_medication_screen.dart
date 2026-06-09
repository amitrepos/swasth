// Modal bottom-sheet for logging medicines (NUO-127).
//
// Per-user feedback: medication-add is a POPUP (modal bottom-sheet), not a
// full page like BP/glucose. Patients (Sunita persona) typically take 3–5
// meds at one sitting, so the sheet supports CHAINED logging: after each
// successful save, the form clears and a green banner shows the last-saved
// name. The user keeps logging until they tap "Done", which pops the sheet
// and the parent list refreshes.
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../models/medication_model.dart';
import '../services/api_exception.dart';
import '../services/error_mapper.dart';
import '../services/medication_service.dart';
import '../services/storage_service.dart';
import '../utils/medication_period_detector.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/medication_photo_thumbnail.dart';

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
    backgroundColor: AppColors.transparent,
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
  final PlatformFile? initialPhoto;
  const AddMedicationSheet({
    super.key,
    required this.profileId,
    this.initialMedication,
    this.initialPhoto,
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
  DateTime _selectedDate = DateTime.now();
  String _intakePeriod = detectMedicationIntakePeriod();
  bool _saving = false;
  int _savedCount = 0;
  String? _lastSavedName;
  PlatformFile? _selectedPhoto;

  bool get _isEditMode => widget.initialMedication != null;

  @override
  void initState() {
    super.initState();
    _selectedPhoto = widget.initialPhoto;
    final m = widget.initialMedication;
    if (m != null) {
      _nameCtl.text = m.name;
      _doseCtl.text = m.dose ?? '';
      _freqCtl.text = m.frequency ?? '';
      _notesCtl.text = m.notes ?? '';
      _selectedDate = DateTime(
        m.takenAt.toLocal().year,
        m.takenAt.toLocal().month,
        m.takenAt.toLocal().day,
      );
      _intakePeriod = m.intakePeriod;
    } else {
      _intakePeriod = detectMedicationIntakePeriod();
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

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (d == null) return;
    if (!mounted) return;
    setState(() => _selectedDate = d);
  }

  DateTime get _computedTakenAt =>
      takenAtFromDateAndPeriod(_selectedDate, _intakePeriod);

  void _resetForm() {
    _nameCtl.clear();
    _doseCtl.clear();
    _freqCtl.clear();
    _notesCtl.clear();
    _formKey.currentState?.reset();
    setState(() {
      _selectedDate = DateTime.now();
      _intakePeriod = detectMedicationIntakePeriod();
      _saving = false;
      _selectedPhoto = null;
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
            intakePeriod: _intakePeriod,
            takenAt: _computedTakenAt,
            notes: _notesCtl.text.trim(),
          ),
          token,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      } else {
        await MedicationService().saveMedicationWithPhoto(
          MedicationCreate(
            profileId: widget.profileId,
            name: savedName,
            dose: _doseCtl.text.trim().isEmpty ? null : _doseCtl.text.trim(),
            frequency: _freqCtl.text.trim().isEmpty
                ? null
                : _freqCtl.text.trim(),
            intakePeriod: _intakePeriod,
            takenAt: _computedTakenAt,
            notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
          ),
          token,
          photo: _selectedPhoto,
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
      final l10n = AppLocalizations.of(context)!;
      final message = _selectedPhoto != null
          ? ErrorMapper.medicationPhotoSaveMessage(l10n, e)
          : ErrorMapper.userMessage(l10n, e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;
    setState(() => _selectedPhoto = result.files.first);
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
          color: AppColors.surface,
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
                color: AppColors.textTertiary,
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
                        color: AppColors.textPrimary,
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
                  color: AppColors.successMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.successBorder),
                ),
                child: Row(
                  key: const Key('medication-saved-banner'),
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _savedCount > 1
                            ? l10n.medicationsFormSavedBannerMulti(
                                _lastSavedName!,
                                _savedCount,
                              )
                            : l10n.medicationsFormSavedBanner(_lastSavedName!),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
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
                        decoration: InputDecoration(
                          labelText: l10n.medicationsFormNameLabel,
                          hintText: l10n.medicationsFormNameHint,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.medicationsFormNameRequired
                            : null,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('medication-dose-field'),
                        controller: _doseCtl,
                        decoration: InputDecoration(
                          labelText: l10n.medicationsFormDoseLabel,
                          hintText: l10n.medicationsFormDoseHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _freqCtl,
                        decoration: InputDecoration(
                          labelText: l10n.medicationsFormFrequencyLabel,
                          hintText: l10n.medicationsFormFrequencyHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_isEditMode) ...[
                        Text(
                          l10n.medicationsAddPhotoLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            l10n.medicationsPhotoWhy,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            MedicationPhotoThumbnail(
                              hasPhoto: _selectedPhoto != null,
                              bytes: _selectedPhoto?.bytes,
                              size: 64,
                              onTap: _saving ? null : _pickPhoto,
                              semanticsLabel: _selectedPhoto == null
                                  ? l10n.medicationsAddPhoto
                                  : l10n.medicationsChangePhoto,
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: _saving ? null : _pickPhoto,
                              child: Text(
                                _selectedPhoto == null
                                    ? l10n.medicationsAddPhoto
                                    : l10n.medicationsChangePhoto,
                              ),
                            ),
                            if (_selectedPhoto != null)
                              TextButton(
                                onPressed: _saving
                                    ? null
                                    : () =>
                                          setState(() => _selectedPhoto = null),
                                child: Text(l10n.medicationsRemovePhoto),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_isEditMode) ...[
                        Text(
                          l10n.medicationsPhotoCannotChangeAfterSave,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.medicationsPhotoCannotChangeHint,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        l10n.medicationsFormPeriodLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        key: const Key('medication-period-chips'),
                        spacing: 8,
                        runSpacing: 8,
                        children: medicationIntakePeriods.map<Widget>((period) {
                          final selected = _intakePeriod == period;
                          return SizedBox(
                            height: 48,
                            child: ChoiceChip(
                              key: Key('medication-period-$period'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              avatar: selected
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: AppColors.primary,
                                    )
                                  : null,
                              label: Text(medicationPeriodLabel(l10n, period)),
                              selected: selected,
                              onSelected: _saving
                                  ? null
                                  : (_) =>
                                        setState(() => _intakePeriod = period),
                              selectedColor: AppColors.bgPill,
                              labelStyle: TextStyle(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.medicationsFormDateLabel,
                            border: const OutlineInputBorder(),
                          ),
                          child: Text(DateFormat.yMMMd().format(_selectedDate)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          l10n.medicationsFormRecordedTimeHint(
                            DateFormat.jm().format(
                              localAnchorDateTime(_selectedDate, _intakePeriod),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesCtl,
                        decoration: InputDecoration(
                          labelText: l10n.medicationsFormNotesLabel,
                          hintText: l10n.medicationsFormNotesHint,
                          border: const OutlineInputBorder(),
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
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.separator)),
              ),
              child: Column(
                children: [
                  if (_saving && _selectedPhoto != null) ...[
                    LinearProgressIndicator(
                      key: const Key('medication-photo-upload-progress'),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        l10n.medicationsUploadingPhoto,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
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
                                  AppColors.onPrimary,
                                ),
                              ),
                            )
                          : const Icon(Icons.add, size: 20),
                      label: Text(
                        _isEditMode
                            ? l10n.medicationsSaveChanges
                            : (_savedCount == 0
                                  ? l10n.medicationsFormSave
                                  : l10n.medicationsFormSaveAndMore),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
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
                              ? l10n.medicationsFormDoneLogged(_savedCount)
                              : l10n.medicationsFormDone,
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
