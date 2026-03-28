import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/ocr_service.dart';
import '../services/health_reading_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';

class ReadingConfirmationScreen extends StatefulWidget {
  final OcrResult? ocrResult;

  /// 'glucose' or 'blood_pressure'
  final String deviceType;
  final int profileId;

  const ReadingConfirmationScreen({
    super.key,
    required this.ocrResult,
    required this.deviceType,
    required this.profileId,
  });

  @override
  State<ReadingConfirmationScreen> createState() => _ReadingConfirmationScreenState();
}

class _ReadingConfirmationScreenState extends State<ReadingConfirmationScreen> {
  final _glucoseController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();

  String? _mealContext; // 'fasting', 'before_meal', 'after_meal'
  DateTime _readingTime = DateTime.now();
  bool _isSaving = false;
  bool _isEditing = false;

  final _readingService = HealthReadingService();
  final _storageService = StorageService();

  bool get isGlucose => widget.deviceType == 'glucose';

  @override
  void initState() {
    super.initState();
    _prefillFromOcr();
  }

  void _prefillFromOcr() {
    final r = widget.ocrResult;
    if (r == null) return;

    if (isGlucose && r.glucoseValue != null) {
      _glucoseController.text = r.glucoseValue!.toStringAsFixed(0);
    } else if (!isGlucose) {
      if (r.systolic != null) _systolicController.text = r.systolic!.toStringAsFixed(0);
      if (r.diastolic != null) _diastolicController.text = r.diastolic!.toStringAsFixed(0);
      if (r.pulse != null) _pulseController.text = r.pulse!.toStringAsFixed(0);
    }
  }

  bool get _ocrSucceeded {
    if (widget.ocrResult == null) return false;
    return widget.ocrResult!.hasValue;
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _readingTime,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_readingTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      _readingTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;

    if (isGlucose) {
      final v = double.tryParse(_glucoseController.text.trim());
      if (v == null || v < 20 || v > 600) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.glucoseValidation)),
        );
        return;
      }
    } else {
      final sys = double.tryParse(_systolicController.text.trim());
      final dia = double.tryParse(_diastolicController.text.trim());
      if (sys == null || sys < 60 || sys > 250) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.systolicValidation)),
        );
        return;
      }
      if (dia == null || dia < 40 || dia > 150) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.diastolicValidation)),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Not authenticated');

      HealthReading reading;

      if (isGlucose) {
        final value = double.parse(_glucoseController.text.trim());
        reading = HealthReading(
          id: 0,
          profileId: widget.profileId,
          readingType: 'glucose',
          glucoseValue: value,
          glucoseUnit: 'mg/dL',
          valueNumeric: value,
          unitDisplay: 'mg/dL',
          statusFlag: _glucoseStatus(value),
          notes: _mealContext,
          readingTimestamp: _readingTime,
          createdAt: DateTime.now(),
        );
      } else {
        final sys = double.parse(_systolicController.text.trim());
        final dia = double.parse(_diastolicController.text.trim());
        final pulse = double.tryParse(_pulseController.text.trim());
        reading = HealthReading(
          id: 0,
          profileId: widget.profileId,
          readingType: 'blood_pressure',
          systolic: sys,
          diastolic: dia,
          pulseRate: pulse,
          bpUnit: 'mmHg',
          valueNumeric: sys,
          unitDisplay: 'mmHg',
          statusFlag: _bpStatus(sys, dia),
          notes: null,
          readingTimestamp: _readingTime,
          createdAt: DateTime.now(),
        );
      }

      await _readingService.saveReading(reading, token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.readingSavedSuccess)),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HistoryScreen(profileId: widget.profileId),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _glucoseStatus(double v) {
    if (v < 70) return 'LOW';
    if (v <= 130) return 'NORMAL';
    if (v <= 180) return 'HIGH';
    return 'CRITICAL';
  }

  String _bpStatus(double sys, double dia) {
    if (sys > 140 || dia > 90) return 'HIGH - STAGE 2';
    if (sys > 131 || dia > 86) return 'HIGH - STAGE 1';
    if (sys < 90 || dia < 60) return 'LOW';
    return 'NORMAL';
  }

  @override
  void dispose() {
    _glucoseController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isGlucose ? l10n.glucoseReadingTitle : l10n.bpReadingTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_ocrSucceeded && !_isEditing)
              _OcrResultBanner(
                ocrResult: widget.ocrResult!,
                deviceType: widget.deviceType,
                onEdit: () => setState(() => _isEditing = true),
              )
            else
              _ManualEntryHint(ocrFailed: !_ocrSucceeded),

            const SizedBox(height: 24),

            if (isGlucose) ...[
              _inputField(
                controller: _glucoseController,
                label: l10n.glucoseValueLabel,
                suffix: 'mg/dL',
                hint: 'e.g. 153',
              ),
            ] else ...[
              _inputField(
                controller: _systolicController,
                label: l10n.systolicLabel,
                suffix: 'mmHg',
                hint: 'e.g. 128',
              ),
              const SizedBox(height: 12),
              _inputField(
                controller: _diastolicController,
                label: l10n.diastolicLabel,
                suffix: 'mmHg',
                hint: 'e.g. 82',
              ),
              const SizedBox(height: 12),
              _inputField(
                controller: _pulseController,
                label: l10n.pulseLabel,
                suffix: 'bpm',
                hint: 'e.g. 72',
              ),
            ],

            if (isGlucose) ...[
              const SizedBox(height: 24),
              Text(
                l10n.mealContextSection,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _mealChip(l10n.fasting, 'fasting'),
                  _mealChip(l10n.beforeMeal, 'before_meal'),
                  _mealChip(l10n.afterMeal, 'after_meal'),
                ],
              ),
            ],

            const SizedBox(height: 24),

            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.readingTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          DateFormat('MMM d, yyyy  h:mm a').format(_readingTime),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.edit, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.saveReading, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _mealChip(String label, String value) {
    final selected = _mealContext == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _mealContext = v ? value : null),
    );
  }
}

/// Shown when OCR successfully extracted a value.
class _OcrResultBanner extends StatelessWidget {
  final OcrResult ocrResult;
  final String deviceType;
  final VoidCallback onEdit;

  const _OcrResultBanner({
    required this.ocrResult,
    required this.deviceType,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String valueText;
    if (deviceType == 'glucose') {
      valueText = ocrResult.isHiLo
          ? (ocrResult.glucoseValue! >= 600 ? 'HI (>600 mg/dL)' : 'LO (<20 mg/dL)')
          : '${ocrResult.glucoseValue!.toStringAsFixed(0)} mg/dL';
    } else {
      valueText =
          '${ocrResult.systolic!.toStringAsFixed(0)} / ${ocrResult.diastolic!.toStringAsFixed(0)} mmHg'
          '${ocrResult.pulse != null ? '  •  ${ocrResult.pulse!.toStringAsFixed(0)} bpm' : ''}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.statusNormal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.statusNormal.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.statusNormal),
              const SizedBox(width: 8),
              Text(l10n.ocrSuccessPrefix,
                  style: const TextStyle(color: AppColors.statusNormal, fontWeight: FontWeight.w500)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 14),
                label: Text(l10n.ocrEditButton),
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valueText,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.ocrConfirmHint,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Shown when OCR failed or returned no value.
class _ManualEntryHint extends StatelessWidget {
  final bool ocrFailed;

  const _ManualEntryHint({required this.ocrFailed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = ocrFailed ? AppColors.iosOrange : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ocrFailed ? l10n.ocrFailedMessage : l10n.manualEntryHint,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
