// Edit-existing-reading screen for BP, glucose, and weight.
// Related: lib/screens/history_screen.dart, lib/services/health_reading_service.dart
// Backend: PUT /api/readings/{id} (routes_health.py).
//
// reading_type is immutable on the backend — we only show fields
// relevant to the stored type. Server recomputes status_flag,
// value_numeric, unit_display.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swasth_app/l10n/app_localizations.dart';

import '../services/error_mapper.dart';
import '../services/health_reading_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class EditReadingScreen extends StatefulWidget {
  final HealthReading reading;
  const EditReadingScreen({super.key, required this.reading});

  @override
  State<EditReadingScreen> createState() => _EditReadingScreenState();
}

class _EditReadingScreenState extends State<EditReadingScreen> {
  final _service = HealthReadingService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _glucose;
  late TextEditingController _systolic;
  late TextEditingController _diastolic;
  late TextEditingController _pulse;
  late TextEditingController _weight;
  late TextEditingController _notes;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.reading;
    _glucose = TextEditingController(
      text: r.glucoseValue != null ? r.glucoseValue!.toStringAsFixed(1) : '',
    );
    _systolic = TextEditingController(
      text: r.systolic != null ? r.systolic!.toStringAsFixed(0) : '',
    );
    _diastolic = TextEditingController(
      text: r.diastolic != null ? r.diastolic!.toStringAsFixed(0) : '',
    );
    _pulse = TextEditingController(
      text: r.pulseRate != null ? r.pulseRate!.toStringAsFixed(0) : '',
    );
    _weight = TextEditingController(
      text: r.weightValue != null ? r.weightValue!.toStringAsFixed(1) : '',
    );
    _notes = TextEditingController(text: r.notes ?? '');
  }

  @override
  void dispose() {
    _glucose.dispose();
    _systolic.dispose();
    _diastolic.dispose();
    _pulse.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _validateGlucose(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.glucoseValidation;
    final d = double.tryParse(v.trim());
    if (d == null || d < 20 || d > 600) return l10n.glucoseValidation;
    return null;
  }

  String? _validateSystolic(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.systolicValidation;
    final d = double.tryParse(v.trim());
    if (d == null || d < 60 || d > 260) return l10n.systolicValidation;
    return null;
  }

  String? _validateDiastolic(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.diastolicValidation;
    final d = double.tryParse(v.trim());
    if (d == null || d < 30 || d > 160) return l10n.diastolicValidation;
    return null;
  }

  String? _validatePulse(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final d = double.tryParse(v.trim());
    if (d == null || d < 30 || d > 220) {
      return AppLocalizations.of(context)!.pulseLabel;
    }
    return null;
  }

  String? _validateWeight(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.weightValidation;
    final d = double.tryParse(v.trim());
    if (d == null || d < 1 || d > 400) return l10n.weightValidation;
    return null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final token = await StorageService().getToken();
      if (token == null) throw Exception('Not authenticated');

      final updates = <String, dynamic>{};
      final type = widget.reading.readingType;

      if (type == 'glucose') {
        updates['glucose_value'] = double.parse(_glucose.text.trim());
      } else if (type == 'blood_pressure') {
        updates['systolic'] = double.parse(_systolic.text.trim());
        updates['diastolic'] = double.parse(_diastolic.text.trim());
        if (_pulse.text.trim().isNotEmpty) {
          updates['pulse_rate'] = double.parse(_pulse.text.trim());
        }
      } else if (type == 'weight') {
        updates['weight_value'] = double.parse(_weight.text.trim());
      }
      updates['notes'] = _notes.text.trim().isEmpty ? null : _notes.text.trim();

      await _service.updateReading(widget.reading.id, updates, token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.readingUpdated),
          backgroundColor: AppColors.statusNormal,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) await ErrorMapper.showSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final type = widget.reading.readingType;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editReading)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (type == 'glucose')
                TextFormField(
                  key: const Key('edit_glucose_value'),
                  controller: _glucose,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: '${l10n.glucoseValueLabel} (${widget.reading.unitDisplay})',
                  ),
                  validator: _validateGlucose,
                ),
              if (type == 'blood_pressure') ...[
                TextFormField(
                  key: const Key('edit_systolic'),
                  controller: _systolic,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l10n.systolicLabel),
                  validator: _validateSystolic,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('edit_diastolic'),
                  controller: _diastolic,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l10n.diastolicLabel),
                  validator: _validateDiastolic,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('edit_pulse'),
                  controller: _pulse,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l10n.pulseLabel),
                  validator: _validatePulse,
                ),
              ],
              if (type == 'weight')
                TextFormField(
                  key: const Key('edit_weight_value'),
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: '${l10n.weightLabel} (${widget.reading.unitDisplay})',
                  ),
                  validator: _validateWeight,
                ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('edit_notes'),
                controller: _notes,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.notes),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('edit_reading_save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
