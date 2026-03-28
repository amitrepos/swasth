import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/health_reading_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  final int profileId;
  const HistoryScreen({super.key, required this.profileId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HealthReadingService _readingService = HealthReadingService();
  bool _isLoading = true;
  List<HealthReading> _readings = [];
  String? _filterType; // null, 'glucose', or 'blood_pressure'

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    setState(() => _isLoading = true);

    try {
      final token = await StorageService().getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final readings = await _readingService.getReadings(
        token: token,
        profileId: widget.profileId,
        readingType: _filterType,
        limit: 100,
      );

      setState(() {
        _readings = readings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    }
  }

  Future<void> _deleteReading(int id) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteReading),
        content: Text(l10n.deleteReadingConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token = await StorageService().getToken();
        if (token == null) throw Exception('Not authenticated');

        await _readingService.deleteReading(id, token);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.readingDeleted),
              backgroundColor: Colors.green,
            ),
          );
          _loadReadings();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting reading: $e')),
          );
        }
      }
    }
  }

  String _localizedStatus(String? flag, AppLocalizations l10n) {
    switch (flag) {
      case 'NORMAL':
        return l10n.statusNormal;
      case 'ELEVATED':
        return l10n.statusElevated;
      case 'HIGH - STAGE 1':
        return l10n.statusHighStage1;
      case 'HIGH - STAGE 2':
        return l10n.statusHighStage2;
      case 'LOW':
        return l10n.statusLow;
      case 'CRITICAL':
        return l10n.statusCritical;
      default:
        return flag ?? '';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'NORMAL':
        return AppColors.statusNormal;
      case 'ELEVATED':
        return AppColors.statusElevated;
      case 'HIGH':
      case 'HIGH - STAGE 1':
      case 'HIGH - STAGE 2':
        return AppColors.statusHigh;
      case 'CRITICAL':
        return AppColors.statusCritical;
      case 'LOW':
        return AppColors.statusLow;
      default:
        return AppColors.statusLow;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'glucose':
        return Icons.water_drop;
      case 'blood_pressure':
        return Icons.favorite;
      default:
        return Icons.medical_services;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.filterByType,
            onSelected: (value) {
              setState(() {
                _filterType = value == 'all' ? null : value;
                _loadReadings();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text(l10n.allReadings)),
              PopupMenuItem(value: 'glucose', child: Text(l10n.glucoseOnly)),
              PopupMenuItem(value: 'blood_pressure', child: Text(l10n.bpOnly)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReadings,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _readings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noReadingsYet,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.noReadingsSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReadings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _readings.length,
                    itemBuilder: (context, index) {
                      final reading = _readings[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(reading.statusFlag)
                                .withOpacity(0.1),
                            child: Icon(
                              _getTypeIcon(reading.readingType),
                              color: _getStatusColor(reading.statusFlag),
                            ),
                          ),
                          title: Text(
                            reading.displayValue,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(reading.statusFlag).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _localizedStatus(reading.statusFlag, l10n),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getStatusColor(reading.statusFlag),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy • hh:mm a')
                                    .format(reading.readingTimestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red.shade300,
                            onPressed: () => _deleteReading(reading.id),
                            tooltip: l10n.delete,
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
