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
import '../utils/medication_period_detector.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final dateTime = DateFormat.yMMMd().add_jm().format(med.takenAt.toLocal());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.medicationsDeleteTitle),
        content: Text(l10n.medicationsDeleteBody(med.name, dateTime)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.danger),
            ),
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
    final l10n = AppLocalizations.of(context)!;
    final showActions = _canEdit && _canWriteRegion;
    final emptyDash = l10n.medicationsCellEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.medicationsScreenTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      floatingActionButton: showActions
          ? FloatingActionButton.extended(
              key: const Key('medications-add-fab'),
              onPressed: _openAddScreen,
              icon: const Icon(Icons.add),
              label: Text(l10n.medicationsLogFab),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meds.isEmpty
          ? _EmptyState(canEdit: showActions, onAdd: _openAddScreen)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Card(
                    key: const Key('medications-table'),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.glassCardBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 32,
                        ),
                        width: (MediaQuery.of(context).size.width - 32) < 720
                            ? 720
                            : (MediaQuery.of(context).size.width - 32),
                        child: Table(
                          columnWidths: {
                            0: const FlexColumnWidth(1.2),
                            1: const FlexColumnWidth(1.4),
                            2: const FlexColumnWidth(1.0),
                            3: const FlexColumnWidth(1.0),
                            4: const FlexColumnWidth(2.0),
                            if (showActions) 5: const FixedColumnWidth(104),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: AppColors.bgPage,
                              ),
                              children: [
                                _buildHeaderCell(l10n.medicationsColDateWhen),
                                _buildHeaderCell(l10n.medicationsColMedicine),
                                _buildHeaderCell(l10n.medicationsColDose),
                                _buildHeaderCell(l10n.medicationsColFrequency),
                                _buildHeaderCell(l10n.medicationsColNotes),
                                if (showActions)
                                  _buildHeaderCell(l10n.medicationsColActions),
                              ],
                            ),
                            ..._meds.map((m) {
                              return TableRow(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.separator,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                children: [
                                  _buildDataCell(
                                    '${DateFormat.MMMd().format(m.takenAt.toLocal())} · ${medicationPeriodLabel(l10n, m.intakePeriod)}',
                                    color: AppColors.textSecondary,
                                  ),
                                  _buildDataCell(m.name, isBold: true),
                                  _buildDataCell(m.dose ?? emptyDash),
                                  _buildDataCell(m.frequency ?? emptyDash),
                                  _buildNotesDataCell(m.notes, emptyDash),
                                  if (showActions)
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Semantics(
                                              label: l10n
                                                  .medicationsEditSemantics(
                                                    m.name,
                                                  ),
                                              button: true,
                                              child: IconButton(
                                                key: Key(
                                                  'medications-edit-${m.id}',
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  color: AppColors.primary,
                                                  size: 20,
                                                ),
                                                onPressed: () async {
                                                  final saved =
                                                      await showAddMedicationSheet(
                                                        context,
                                                        profileId:
                                                            widget.profileId,
                                                        initialMedication: m,
                                                      );
                                                  if (saved == true) _load();
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Semantics(
                                              label: l10n
                                                  .medicationsDeleteSemantics(
                                                    m.name,
                                                  ),
                                              button: true,
                                              child: IconButton(
                                                key: Key(
                                                  'medications-delete-${m.id}',
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: AppColors.danger,
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _confirmDelete(m),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          color: color ?? AppColors.textPrimary,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildNotesDataCell(String? notes, String emptyDash) {
    final hasNotes = notes != null && notes.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        hasNotes ? notes : emptyDash,
        style: TextStyle(
          fontStyle: hasNotes ? FontStyle.italic : FontStyle.normal,
          color: hasNotes ? AppColors.textSecondary : AppColors.textPrimary,
          fontSize: 13,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.medication_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.medicationsEmptyTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.medicationsEmptyBody,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (canEdit) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l10n.medicationsLogFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
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
