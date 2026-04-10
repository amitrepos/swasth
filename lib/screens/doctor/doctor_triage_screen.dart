import 'package:flutter/material.dart';
import '../../services/doctor_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../login_screen.dart';
import 'doctor_patient_detail_screen.dart';

/// Doctor's main screen — triage board showing patients sorted by criticality.
class DoctorTriageScreen extends StatefulWidget {
  const DoctorTriageScreen({super.key});

  @override
  State<DoctorTriageScreen> createState() => _DoctorTriageScreenState();
}

class _DoctorTriageScreenState extends State<DoctorTriageScreen> {
  final _doctorService = DoctorService();
  final _storage = StorageService();

  List<Map<String, dynamic>> _patients = [];
  Map<String, dynamic>? _doctorProfile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final token = await _storage.getToken();
    if (token == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _doctorService.getMyProfile(token),
        _doctorService.getTriageBoard(token),
      ]);

      if (!mounted) return;
      setState(() {
        _doctorProfile = results[0] as Map<String, dynamic>;
        _patients = (results[1] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _storage.clearAll();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  List<Map<String, dynamic>> _filterByStatus(String status) {
    return _patients.where((p) => p['triage_status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _doctorProfile?['full_name'] ?? 'Doctor Portal',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_doctorProfile?['doctor_code'] != null)
              Text(
                'Code: ${_doctorProfile!['doctor_code']}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('refreshTriageBtn'),
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _loadData,
          ),
          IconButton(
            key: const Key('logoutBtn'),
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _patients.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(onRefresh: _loadData, child: _buildTriageBoard()),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.medical_services_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No patients connected yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your doctor code with patients:\n${_doctorProfile?['doctor_code'] ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Patients enter this code in their app to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriageBoard() {
    final critical = _filterByStatus('critical');
    final attention = _filterByStatus('attention');
    final stable = _filterByStatus('stable');
    final noData = _filterByStatus('no_data');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Summary bar
        _buildSummaryBar(
          critical.length,
          attention.length,
          stable.length,
          noData.length,
        ),
        const SizedBox(height: 16),

        // Critical section (expanded, red)
        if (critical.isNotEmpty) ...[
          _buildSectionHeader(
            'CRITICAL',
            critical.length,
            AppColors.danger,
            Icons.warning_rounded,
          ),
          ...critical.map(_buildPatientCard),
          const SizedBox(height: 16),
        ],

        // Attention section (expanded, amber)
        if (attention.isNotEmpty) ...[
          _buildSectionHeader(
            'NEEDS ATTENTION',
            attention.length,
            AppColors.amber,
            Icons.bolt,
          ),
          ...attention.map(_buildPatientCard),
          const SizedBox(height: 16),
        ],

        // Stable section (collapsed by default, green)
        if (stable.isNotEmpty) ...[
          _buildCollapsibleSection(
            'STABLE',
            stable,
            AppColors.success,
            Icons.check_circle,
          ),
          const SizedBox(height: 16),
        ],

        // No data section (collapsed by default, grey)
        if (noData.isNotEmpty) ...[
          _buildCollapsibleSection(
            'NO DATA',
            noData,
            AppColors.textSecondary,
            Icons.access_time,
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryBar(int critical, int attention, int stable, int noData) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '${_patients.length} patients',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _buildCountBadge(critical, AppColors.danger),
          const SizedBox(width: 8),
          _buildCountBadge(attention, AppColors.amber),
          const SizedBox(width: 8),
          _buildCountBadge(stable, AppColors.success),
          if (noData > 0) ...[
            const SizedBox(width: 8),
            _buildCountBadge(noData, AppColors.textSecondary),
          ],
        ],
      ),
    );
  }

  Widget _buildCountBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            '$title ($count)',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection(
    String title,
    List<Map<String, dynamic>> patients,
    Color color,
    IconData icon,
  ) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(icon, size: 18, color: color),
        title: Text(
          '$title (${patients.length})',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        initiallyExpanded: false,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        children: patients.map(_buildPatientCard).toList(),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final status = patient['triage_status'] as String? ?? 'no_data';
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);
    final triageReason = patient['triage_reason'] as String?;

    final conditions = patient['medical_conditions'] as List<dynamic>?;
    final conditionsText = conditions?.join(', ') ?? '';

    final lastValue = patient['last_reading_value'] as String?;
    final lastType = patient['last_reading_type'] as String?;
    final lastAt = patient['last_reading_at'] as String?;
    final compliance = patient['compliance_7d'] as int? ?? 0;
    final trend = patient['trend_direction'] as String?;

    return GlassCard(
      key: Key('patientCard_${patient['profile_id']}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorPatientDetailScreen(
                profileId: patient['profile_id'] as int,
                profileName: patient['profile_name'] as String? ?? 'Patient',
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + status badge
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    patient['profile_name'] as String? ?? 'Unknown',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Age, gender, conditions
            Text(
              [
                if (patient['age'] != null)
                  '${patient['age']}${patient['gender'] != null ? patient['gender'].toString().substring(0, 1) : ''}',
                if (conditionsText.isNotEmpty) conditionsText,
              ].join(' - '),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),

            // Triage reason tag
            if (triageReason != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  triageReason,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            if (lastValue != null) ...[
              const SizedBox(height: 8),
              // Last reading
              Row(
                children: [
                  Text(
                    '${_readingTypeLabel(lastType)}: ',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    lastValue,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (trend != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      trend == 'worsening'
                          ? Icons.trending_up
                          : trend == 'improving'
                          ? Icons.trending_down
                          : Icons.trending_flat,
                      size: 16,
                      color: trend == 'worsening'
                          ? AppColors.danger
                          : trend == 'improving'
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ],
                  const Spacer(),
                  // Time ago
                  if (lastAt != null)
                    Text(
                      _timeAgo(lastAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 6),

            // Compliance dots
            Row(
              children: [
                ...List.generate(7, (i) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < compliance
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                  );
                }),
                const SizedBox(width: 4),
                Text(
                  '$compliance/7 days',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'critical':
        return Icons.warning_rounded;
      case 'attention':
        return Icons.bolt;
      case 'stable':
        return Icons.check_circle;
      default:
        return Icons.access_time;
    }
  }

  String _readingTypeLabel(String? type) {
    switch (type) {
      case 'blood_pressure':
        return 'BP';
      case 'glucose':
        return 'Glucose';
      case 'spo2':
        return 'SpO2';
      default:
        return 'Reading';
    }
  }

  String _timeAgo(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}
