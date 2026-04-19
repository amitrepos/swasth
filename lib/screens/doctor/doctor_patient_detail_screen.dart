import 'package:flutter/material.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../../services/api_exception.dart';
import '../../services/doctor_service.dart';
import '../../services/error_mapper.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// Doctor's patient detail view — quick stats, readings, notes.
class DoctorPatientDetailScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const DoctorPatientDetailScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  State<DoctorPatientDetailScreen> createState() =>
      _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  final _doctorService = DoctorService();
  final _storage = StorageService();
  final _noteController = TextEditingController();

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _readings = [];
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  String? _error;
  bool _addingNote = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final token = await _storage.getToken();
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _doctorService.getPatientProfile(token, widget.profileId),
        _doctorService.getPatientSummary(token, widget.profileId),
        _doctorService.getPatientReadings(token, widget.profileId),
        _doctorService.getNotes(token, widget.profileId),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _summary = results[1] as Map<String, dynamic>;
        _readings = (results[2] as List).cast<Map<String, dynamic>>();
        _notes = (results[3] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is UnauthorizedException) {
        await ErrorMapper.showSnack(context, e);
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = ErrorMapper.userMessage(l10n, e);
        _loading = false;
      });
    }
  }

  Future<void> _submitNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    final token = await _storage.getToken();
    if (token == null) return;

    setState(() => _addingNote = true);
    try {
      await _doctorService.addNote(token, widget.profileId, text);
      _noteController.clear();
      // Reload notes
      final notes = await _doctorService.getNotes(token, widget.profileId);
      if (!mounted) return;
      setState(() {
        _notes = notes.cast<Map<String, dynamic>>();
        _addingNote = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _addingNote = false);
      await ErrorMapper.showSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.profileName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAll,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(onRefresh: _loadAll, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Patient profile card
        _buildProfileCard(),
        const SizedBox(height: 16),

        // Quick stats
        _buildQuickStats(),
        const SizedBox(height: 16),

        // NMC disclaimer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgGrouped,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Clinical Decision Support - verify independently',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recent readings
        _buildReadingsSection(),
        const SizedBox(height: 16),

        // Doctor notes
        _buildNotesSection(),
      ],
    );
  }

  Widget _buildProfileCard() {
    if (_profile == null) return const SizedBox.shrink();
    final p = _profile!;
    final conditions = p['medical_conditions'] as List<dynamic>?;
    final bmi = p['bmi'] as num?;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                p['name'] as String? ?? 'Patient',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (p['age'] != null)
                Text(
                  '${p['age']}y ${p['gender'] ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (conditions != null && conditions.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: conditions
                  .map((c) => _buildChip(c.toString()))
                  .toList(),
            ),
          const SizedBox(height: 8),
          if (p['current_medications'] != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.medication,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    p['current_medications'] as String,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          if (bmi != null) ...[
            const SizedBox(height: 4),
            Text(
              'BMI: ${bmi.toStringAsFixed(1)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgGrouped,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _buildQuickStats() {
    if (_summary == null) return const SizedBox.shrink();
    final s = _summary!;
    final glucose = s['glucose'] as Map<String, dynamic>?;
    final bp = s['bp'] as Map<String, dynamic>?;
    final compliance = s['compliance_7d'] as int? ?? 0;
    final triageStatus = s['triage_status'] as String? ?? 'no_data';

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Glucose (7d)',
            glucose?['avg'] != null
                ? '${(glucose!['avg'] as num).toStringAsFixed(0)}'
                : '--',
            '${glucose?['count'] ?? 0} readings',
            AppColors.glucose,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'BP (7d)',
            bp?['avg_systolic'] != null
                ? '${(bp!['avg_systolic'] as num).toStringAsFixed(0)}/${(bp['avg_diastolic'] as num).toStringAsFixed(0)}'
                : '--',
            '${bp?['count'] ?? 0} readings',
            AppColors.bloodPressure,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Compliance',
            '$compliance/7',
            triageStatus.toUpperCase(),
            _statusColor(triageStatus),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReadingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Readings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (_readings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No readings in the last 30 days',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          ..._readings.take(10).map(_buildReadingRow),
        if (_readings.length > 10)
          TextButton(
            onPressed: () {},
            child: Text('Show all ${_readings.length} readings'),
          ),
      ],
    );
  }

  Widget _buildReadingRow(Map<String, dynamic> reading) {
    final type = reading['reading_type'] as String?;
    final statusFlag = reading['status_flag'] as String? ?? '';
    final timestamp = reading['reading_timestamp'] as String?;

    String valueText;
    Color valueColor;

    if (type == 'blood_pressure') {
      final sys = (reading['systolic'] as num?)?.toStringAsFixed(0) ?? '--';
      final dia = (reading['diastolic'] as num?)?.toStringAsFixed(0) ?? '--';
      valueText = '$sys/$dia mmHg';
    } else if (type == 'glucose') {
      final val =
          (reading['glucose_value'] as num?)?.toStringAsFixed(0) ?? '--';
      final sample = reading['sample_type'] as String? ?? '';
      valueText = '$val mg/dL ${sample.isNotEmpty ? '($sample)' : ''}';
    } else {
      valueText = '${reading['value_numeric']} ${reading['unit_display']}';
    }

    valueColor = _flagColor(statusFlag);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            type == 'blood_pressure' ? Icons.favorite : Icons.bloodtype,
            size: 16,
            color: type == 'blood_pressure'
                ? AppColors.bloodPressure
                : AppColors.glucose,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valueText,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timestamp != null)
                  Text(
                    _formatTimestamp(timestamp),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (statusFlag.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: valueColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusFlag,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Clinical Notes',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 6),
            Text(
              '(Private - patient cannot see)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Add note input
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('noteInput'),
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'Add clinical note...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('submitNoteBtn'),
                icon: _addingNote
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: AppColors.primary),
                onPressed: _addingNote ? null : _submitNote,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Existing notes
        if (_notes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No notes yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          ..._notes.map(_buildNoteCard),
      ],
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final text = note['note_text'] as String? ?? '';
    final createdAt = note['created_at'] as String?;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.edit_note,
                size: 12,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              if (createdAt != null)
                Text(
                  _formatTimestamp(createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              const Spacer(),
              const Text(
                'Clinical observation - not a prescription',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'critical':
        return AppColors.danger;
      case 'attention':
        return AppColors.amber;
      case 'stable':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _flagColor(String flag) {
    final upper = flag.toUpperCase();
    if (upper.contains('CRITICAL') || upper.contains('STAGE 2'))
      return AppColors.danger;
    if (upper.contains('HIGH') || upper.contains('STAGE 1'))
      return AppColors.amber;
    if (upper.contains('LOW')) return AppColors.statusLow;
    if (upper.contains('NORMAL')) return AppColors.success;
    return AppColors.textPrimary;
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
