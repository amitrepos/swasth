import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ble/ble_manager.dart';
import '../ble/bp_service.dart';
import '../theme/app_theme.dart';
import '../ble/glucose_service.dart';
import '../models/glucose_reading.dart';
import '../services/health_reading_service.dart';
import '../services/storage_service.dart';

class DashboardScreen extends StatefulWidget {
  final BluetoothDevice? device;
  final List<BluetoothService> services;
  final String deviceType;
  final bool autoConnect;
  final int profileId;

  const DashboardScreen({
    super.key,
    required this.device,
    required this.services,
    required this.deviceType,
    required this.profileId,
    this.autoConnect = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Glucose state ──────────────────────────────────────────────────────────
  GlucoseReading? _latestGlucoseReading;
  List<GlucoseReading> _allGlucoseReadings = [];

  // ── BP state ───────────────────────────────────────────────────────────────
  BPReading? _latestBPReading;
  List<BPReading> _allBPReadings = [];
  bool _bpLoading = false;

  // ── Shared state ───────────────────────────────────────────────────────────
  String _status = 'Requesting records from device...';
  String _racpResponse = '';
  bool _loading = true;

  bool _glucometerConnected = false;
  bool _bpMeterConnected    = false;
  bool _armbandConnected    = false;
  String _connectedDeviceType = 'Unknown';

  bool _showHistoryPanel = false;
  List<BluetoothService> _discoveredServices = [];

  // ── Connected BP device reference (needed for BPService calls) ─────────────
  BluetoothDevice? _connectedBPDevice;

  @override
  void initState() {
    super.initState();
    if (widget.autoConnect) {
      _startAutoConnect();
    } else if (widget.device != null) {
      _fetchReadings();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Scan helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  // ── Auto scan and connect ──────────────────────────────────────────────────
  Future<void> _startAutoConnect() async {
    final label = widget.deviceType == 'Blood Pressure'
        ? 'BP meter'
        : 'glucometer';

    setState(() {
      _status  = 'Scanning for $label...';
      _loading = true;
    });

    try {
      await _requestPermissions();

      bool found = false;
      BleManager.startScan().listen((results) async {
        if (results.isNotEmpty && !found) {
          ScanResult? target;

          if (widget.deviceType == 'Blood Pressure') {
            target = results.firstWhere(
              (r) => BleManager.deviceType(r) == 'Blood Pressure',
              orElse: () => results.first,
            );
          } else {
            target = results.firstWhere(
              (r) => BleManager.deviceType(r) == 'Glucose',
              orElse: () => results.first,
            );
          }

          found = true;
          _connectToDevice(target);
        }
      });

      await Future.delayed(const Duration(seconds: 20));
      await BleManager.stopScan();

      if (!found && mounted) {
        setState(() {
          _status  = 'No $label found. Make sure it is in transfer mode.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status  = 'Connection error: $e';
          _loading = false;
        });
      }
    }
  }

  // ── Connect to a scan result ───────────────────────────────────────────────
  Future<void> _connectToDevice(ScanResult result) async {
    await BleManager.stopScan();

    final type = BleManager.deviceType(result);
    setState(() => _status = 'Connecting to ${result.device.platformName}...');

    try {
      final services = await BleManager.connectAndDiscover(result.device);

      if (!mounted) return;

      setState(() {
        _discoveredServices     = services;
        _glucometerConnected    = type == 'Glucose';
        _bpMeterConnected       = type == 'Blood Pressure';
        _armbandConnected       = type == 'Unknown';
        _connectedDeviceType    = type;
        _loading                = false;
      });

      if (type == 'Blood Pressure') {
        // ── Omron custom protocol path ────────────────────────────────────
        // Store the device reference so we can call BPService later.
        _connectedBPDevice = result.device;

        // Check if this device uses the custom Omron protocol
        if (BleManager.hasOmronCustomServices(services)) {
          _readBPDataOmron(result.device);
        } else {
          // Standard 0x1810 device — subscribe to 0x2A35 indications
          final bpService = BleManager.findBPService(services);
          if (bpService != null) {
            _subscribeBPStandard(bpService);
          } else {
            setState(() => _status = 'BP service not found on this device.');
          }
        }
      } else if (type == 'Glucose') {
        _fetchReadings();
      } else {
        setState(() => _status = 'Connected to $type device');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status  = 'Connection failed: $e';
          _loading = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Omron custom protocol  (mirrors Python read_bp_data)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _readBPDataOmron(BluetoothDevice device) async {
    setState(() {
      _bpLoading = true;
      _status    = 'Reading BP records via Omron protocol…\n'
                   '➜ Press BT once on device (slow LED = transfer mode)';
    });

    try {
      final result = await BPService.readAllRecords(
        device:     device,
        syncTime:   false,
        onProgress: (msg) {
          if (mounted) setState(() => _status = msg);
        },
      );

      if (!mounted) return;

      setState(() {
        _allBPReadings   = result.readings;
        _latestBPReading = result.latest;
        _bpLoading       = false;
        _status = result.readings.isEmpty
            ? 'No valid BP records found. Try pressing BT first.'
            : 'Found ${result.readings.length} BP record(s)';
      });

      if (result.latest != null) {
        _saveBPReading(result.latest!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bpLoading = false;
          _status    = 'BP read error: $e';
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Standard BT-SIG 0x2A35 path (non-Omron BP devices)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _subscribeBPStandard(BluetoothService service) async {
    setState(() => _status = 'Waiting for BP measurement…');
    try {
      await BPService.subscribeToStandardBPMeasurement(
        service:   service,
        onReading: (reading) {
          if (mounted) {
            setState(() {
              _latestBPReading = reading;
              _allBPReadings.add(reading);
              _status = 'BP reading received';
            });
            _saveBPReading(reading);
          }
        },
        onError: (e) {
          if (mounted) setState(() => _status = 'BP error: $e');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _status = 'BP subscribe error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Glucose RACP flow (unchanged)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchReadings() async {
    final servicesToUse =
        widget.services.isNotEmpty ? widget.services : _discoveredServices;

    if (servicesToUse.isEmpty) {
      setState(() {
        _status  = 'No services discovered.';
        _loading = false;
      });
      return;
    }

    final glucoseService = BleManager.findGlucoseService(servicesToUse);

    if (glucoseService == null) {
      setState(() {
        _status  = 'Glucose service (0x1808) not found.';
        _loading = false;
      });
      return;
    }

    setState(() => _status = 'Fetching glucose records…');

    await GlucoseService.requestAllRecords(
      service: glucoseService,
      onReading: (reading) {
        _saveReadingToDatabase(reading, 'glucose');
        setState(() {
          _allGlucoseReadings.removeWhere(
              (r) => r.sequenceNumber == reading.sequenceNumber);
          _allGlucoseReadings.add(reading);
          _latestGlucoseReading = reading;
          final count = _removeDuplicateReadings(_allGlucoseReadings).length;
          _status  = 'Received $count unique record(s)';
          _loading = false;
        });
      },
      onRacpResponse: (response) {
        setState(() {
          _racpResponse = response;
          _loading      = false;
          if (_allGlucoseReadings.isEmpty) _status = 'RACP: $response';
        });
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Scan for specific device type (device icon tap)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startScanForDevice(String deviceType) async {
    setState(() {
      _status  = 'Scanning for $deviceType…';
      _loading = true;
    });

    try {
      await _requestPermissions();

      bool found = false;

      BleManager.startScan(timeout: const Duration(seconds: 20))
          .listen((results) async {
        if (results.isNotEmpty && !found) {
          ScanResult? selected;

          if (deviceType == 'Blood Pressure') {
            // ── Match exactly like Python: BLESMART / HEM / OMRON name first,
            //    then standard 0x1810 as fallback.
            selected = results.firstWhere(
              (r) => BleManager.isOmronDevice(r),
              orElse: () => results.firstWhere(
                (r) => BleManager.deviceType(r) == 'Blood Pressure',
                orElse: () => results.first,
              ),
            );
          } else if (deviceType == 'Glucose') {
            selected = results.firstWhere(
              (r) => BleManager.deviceType(r) == 'Glucose',
              orElse: () => results.first,
            );
          } else {
            selected = results.first;
          }

          found = true;
          _connectToDevice(selected);
        }
      });

      await Future.delayed(const Duration(seconds: 20));
      await BleManager.stopScan();

      if (!found && mounted) {
        setState(() {
          _status  = 'No $deviceType found. '
                     '${deviceType == 'Blood Pressure' ? 'Press BT on device first.' : 'Turn on your device.'}';
          _loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No $deviceType found nearby'),
          backgroundColor: AppColors.statusElevated,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status  = 'Scan error: $e';
          _loading = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Save helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveBPReading(BPReading reading) async {
    try {
      final token = await StorageService().getToken();
      if (token == null) return;

      // TODO: convert BPReading → HealthReading and call HealthReadingService
      // This mirrors the _saveReadingToDatabase pattern used for glucose.
      print('BP saved: ${reading.systolicMmhg}/${reading.diastolicMmhg} mmHg');
    } catch (e) {
      print('Error saving BP reading: $e');
    }
  }

  Future<void> _saveReadingToDatabase(
      dynamic reading, String deviceType) async {
    try {
      final token = await StorageService().getToken();
      if (token == null) return;

      final healthReading =
          HealthReading.fromGlucoseOrBP(reading, deviceType);
      healthReading.profileId = widget.profileId;
      final readingTimestamp = reading.timestamp ?? DateTime.now();

      final existingReadings = await HealthReadingService().getReadings(
        token: token,
        profileId: widget.profileId,
        limit: 1000,
      );

      final isDuplicate = existingReadings.any((e) =>
          e.readingTimestamp.millisecondsSinceEpoch ==
          readingTimestamp.millisecondsSinceEpoch);

      if (isDuplicate) return;

      final saveResult =
          await HealthReadingService().saveReading(healthReading, token);
      final saved = saveResult['reading'] as HealthReading;
      print('Saved reading ID: ${saved.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved: ${healthReading.displayValue}'),
          backgroundColor: AppColors.statusNormal,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      print('Error saving reading: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Color _glucoseFlagColor(String flag) {
    switch (flag) {
      case 'LOW':       return AppColors.statusElevated;
      case 'NORMAL':    return AppColors.statusNormal;
      case 'HIGH':      return AppColors.statusHigh;
      case 'VERY HIGH': return AppColors.statusCritical;
      default:          return AppColors.statusLow;
    }
  }

  Color _bpCategoryColor(String category) {
    switch (category) {
      case 'NORMAL':         return AppColors.statusNormal;
      case 'ELEVATED':       return AppColors.statusElevated;
      case 'HIGH - STAGE 1': return AppColors.statusHigh;
      case 'HIGH - STAGE 2': return AppColors.statusCritical;
      default:               return AppColors.statusLow;
    }
  }

  IconData _flagIcon(String flag) {
    switch (flag) {
      case 'LOW':       return Icons.arrow_downward;
      case 'NORMAL':    return Icons.check_circle;
      case 'HIGH':      return Icons.warning;
      case 'VERY HIGH': return Icons.dangerous;
      default:          return Icons.help;
    }
  }

  IconData _getDeviceIcon(String type) {
    switch (type) {
      case 'Glucose':       return Icons.water_drop;
      case 'Blood Pressure':return Icons.favorite;
      default:              return Icons.watch;
    }
  }

  Color _getDeviceColor(String type) {
    switch (type) {
      case 'Glucose':        return AppColors.glucose;
      case 'Blood Pressure': return AppColors.bloodPressure;
      default:               return AppColors.statusNormal;
    }
  }

  List<GlucoseReading> _removeDuplicateReadings(
      List<GlucoseReading> readings) {
    final map = <int, GlucoseReading>{};
    for (final r in readings) {
      map[r.sequenceNumber] = r;
    }
    return map.values.toList();
  }

  List<GlucoseReading> _sortReadingsBySequence(
      List<GlucoseReading> readings) {
    final sorted = List<GlucoseReading>.from(readings)
      ..sort((a, b) => b.sequenceNumber.compareTo(a.sequenceNumber));
    return sorted;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Device panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDeviceIcon({
    required IconData icon,
    required String label,
    required bool isConnected,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(alignment: Alignment.center, children: [
          if (isConnected)
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 15, spreadRadius: 2)],
              ),
            ),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected
                  ? color
                  : (isDark ? AppColors.bgPillDark : AppColors.bgPill),
              border: Border.all(
                color: isConnected
                    ? color
                    : (isDark ? AppColors.bgCard2Dark : AppColors.bgCard2),
                width: 2,
              ),
            ),
            child: Icon(icon,
                color: isConnected ? Colors.white : AppColors.textSecondary,
                size: 28),
          ),
        ]),
        const SizedBox(height: 8),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isConnected
                    ? color
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5)),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildDevicePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Tap to connect a device',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                  fontWeight: FontWeight.w500)),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          GestureDetector(
            onTap: () => _handleDeviceTap('Glucose'),
            child: _buildDeviceIcon(
              icon: Icons.water_drop,
              label: AppLocalizations.of(context)!.glucometer,
              isConnected: _glucometerConnected,
              color: AppColors.glucose,
            ),
          ),
          GestureDetector(
            onTap: () => _handleDeviceTap('Blood Pressure'),
            child: _buildDeviceIcon(
              icon: Icons.favorite,
              label: AppLocalizations.of(context)!.bpMeter,
              isConnected: _bpMeterConnected,
              color: AppColors.bloodPressure,
            ),
          ),
          GestureDetector(
            onTap: () => _handleDeviceTap('Armband'),
            child: _buildDeviceIcon(
              icon: Icons.watch,
              label: AppLocalizations.of(context)!.armband,
              isConnected: _armbandConnected,
              color: AppColors.statusNormal,
            ),
          ),
        ]),
      ]),
    );
  }

  void _handleDeviceTap(String deviceType) {
    final isConnected = deviceType == 'Glucose'
        ? _glucometerConnected
        : deviceType == 'Blood Pressure'
            ? _bpMeterConnected
            : _armbandConnected;

    final message = isConnected
        ? '$_connectedDeviceType already connected. Scan for another $deviceType?'
        : 'Scan for $deviceType?';

    // Extra hint for Omron users
    final hint = deviceType == 'Blood Pressure'
        ? '\n\nPress BT on the device once first (slow LED = transfer mode).'
        : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Connect $deviceType'),
        content: Text('$message$hint'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _startScanForDevice(deviceType);
              },
              child: const Text('Scan')),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BP reading card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBPReadingCard(BPReading r) {
    final color = _bpCategoryColor(r.bpCategory);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Category badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3), width: 0.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.favorite, color: color, size: 18),
              const SizedBox(width: 6),
              Text(r.bpCategory,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 20),

          // Main BP value
          Text(
            '${r.systolicMmhg}/${r.diastolicMmhg}',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: color, fontWeight: FontWeight.w700),
          ),
          Text('mmHg',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5))),
          const SizedBox(height: 4),
          Text('MAP: ${r.mapMmhg} mmHg',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5))),

          const Divider(height: 32, thickness: 0.5),

          _detailRow(Icons.monitor_heart, 'Pulse', '${r.pulseBpm} bpm'),
          _detailRow(Icons.person, 'User', 'User ${r.user}'),
          _detailRow(Icons.access_time, 'Time', r.timestamp.length > 19 ? r.timestamp.substring(0, 19) : r.timestamp),
          _detailRow(Icons.tag, 'Seq / Slot', '#${r.seq} / slot ${r.slot}'),
          if (r.flags.irregularHeartbeat)
            _detailRow(Icons.warning_amber, 'Warning', 'Irregular heartbeat'),
          if (r.flags.bodyMovement)
            _detailRow(Icons.warning_amber, 'Warning', 'Body movement'),
          if (!r.checksumOk)
            _detailRow(Icons.error_outline, 'Checksum', 'Failed'),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Glucose reading card (unchanged)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGlucoseReadingCard(GlucoseReading r) {
    final color = _glucoseFlagColor(r.flag);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3), width: 0.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_flagIcon(r.flag), color: color, size: 18),
              const SizedBox(width: 6),
              Text(r.flag,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 20),
          Text(r.mgdl.toStringAsFixed(1),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: color, fontWeight: FontWeight.w700)),
          Text('mg/dL',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5))),
          const SizedBox(height: 4),
          Text('${r.mmol.toStringAsFixed(2)} mmol/L',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5))),
          const Divider(height: 32, thickness: 0.5),
          _detailRow(Icons.tag, 'Sequence', '#${r.sequenceNumber}'),
          _detailRow(Icons.access_time, 'Time',
              r.timestamp.toString().substring(0, 19)),
          _detailRow(Icons.science, 'Sample Type', r.sampleType),
          _detailRow(Icons.location_on, 'Location', r.sampleLocation),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon,
            size: 16,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.4)),
        const SizedBox(width: 8),
        Text('$label: ',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BP history list
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBPHistoryList() {
    if (_allBPReadings.length <= 1) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text('BP History',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${_allBPReadings.length} records',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      ..._allBPReadings.skip(1).map((r) {
        final color = _bpCategoryColor(r.bpCategory);
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 20,
              child: Icon(Icons.favorite, color: color, size: 18),
            ),
            title: Text('${r.systolicMmhg}/${r.diastolicMmhg} mmHg',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Pulse: ${r.pulseBpm} bpm',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(r.timestamp.length > 16 ? r.timestamp.substring(0, 16) : r.timestamp,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(fontSize: 10)),
                ]),
            trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('User ${r.user}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(fontSize: 11)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: color.withOpacity(0.3), width: 0.5),
                    ),
                    child: Text(r.bpCategory,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ),
                ]),
          ),
        );
      }),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Glucose history list (unchanged)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGlucoseHistoryList() {
    final unique = _removeDuplicateReadings(_allGlucoseReadings);
    final sorted = _sortReadingsBySequence(unique);
    if (sorted.length <= 1) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text('All Records',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${sorted.length} records',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      ...sorted.skip(1).map((r) {
        final color = _glucoseFlagColor(r.flag);
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 20,
              child: Icon(_flagIcon(r.flag), color: color, size: 18),
            ),
            title: Text('${r.mgdl.toStringAsFixed(1)} mg/dL',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('${r.mmol.toStringAsFixed(2)} mmol/L',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(r.timestamp.toString().substring(0, 16),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(fontSize: 10)),
                ]),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3), width: 0.5),
              ),
              child: Text(r.flag,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ),
        );
      }),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final deviceName = widget.device?.platformName.isNotEmpty == true
        ? widget.device!.platformName
        : 'Swasth Health Monitor';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final showBPCard     = _latestBPReading != null;
    final showGlucCard   = _latestGlucoseReading != null;
    final showBPHistory  = _allBPReadings.isNotEmpty;
    final showGlucHistory= _allGlucoseReadings.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName),
        actions: [
          if (_allBPReadings.isNotEmpty || _allGlucoseReadings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showFullHistory,
              tooltip: 'View All History',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _allGlucoseReadings  = [];
                _latestGlucoseReading= null;
                _allBPReadings       = [];
                _latestBPReading     = null;
                _loading             = true;
                _status              = 'Refreshing…';
              });
              if (_connectedBPDevice != null) {
                _readBPDataOmron(_connectedBPDevice!);
              } else {
                _fetchReadings();
              }
            },
          ),
          if (widget.device != null)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: () {
                final d = widget.device;
                if (d != null) {
                  BleManager.disconnect(d).then((_) {
                    if (!mounted) return;
                    setState(() {
                      _glucometerConnected = false;
                      _bpMeterConnected    = false;
                      _armbandConnected    = false;
                      _connectedDeviceType = 'Unknown';
                      _connectedBPDevice   = null;
                      _allBPReadings       = [];
                      _latestBPReading     = null;
                      _allGlucoseReadings  = [];
                      _latestGlucoseReading= null;
                      _status              = 'Disconnected';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device disconnected')));
                  });
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // Device panel
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildDevicePanel(),
          ),

          // Status bar
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark
                ? AppColors.insight.withOpacity(0.1)
                : AppColors.insight.withOpacity(0.05),
            child: Row(children: [
              if (_loading || _bpLoading)
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (_loading || _bpLoading) const SizedBox(width: 8),
              Expanded(
                  child: Text(_status,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.insight,
                          fontWeight: FontWeight.w500))),
            ]),
          ),

          // Loading indicator
          if ((_loading || _bpLoading) && !showBPCard && !showGlucCard)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Connecting to device…',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary)),
              ]),
            ),

          // BP reading card
          if (showBPCard) _buildBPReadingCard(_latestBPReading!),

          // Glucose reading card
          if (showGlucCard) _buildGlucoseReadingCard(_latestGlucoseReading!),

          // BP history
          if (showBPHistory) _buildBPHistoryList(),

          // Glucose history
          if (showGlucHistory) _buildGlucoseHistoryList(),

          // RACP response
          if (_racpResponse.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Text('Device response: $_racpResponse',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  void _showFullHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, sc) => Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(_getDeviceIcon(_connectedDeviceType),
                  color: _getDeviceColor(_connectedDeviceType)),
              const SizedBox(width: 8),
              Text('All $_connectedDeviceType Records',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.all(16),
              children: [
                if (_allBPReadings.isNotEmpty) ..._allBPReadings.map((r) {
                  final color = _bpCategoryColor(r.bpCategory);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: color,
                          child: const Icon(Icons.favorite,
                              color: Colors.white, size: 18)),
                      title: Text(
                          '${r.systolicMmhg}/${r.diastolicMmhg} mmHg'),
                      subtitle: Text(
                          '${r.pulseBpm} bpm · User ${r.user} · ${r.bpCategory}'),
                      trailing: Text(r.timestamp.length > 16
                          ? r.timestamp.substring(0, 16)
                          : r.timestamp,
                          style: const TextStyle(fontSize: 11)),
                    ),
                  );
                }),
                if (_allGlucoseReadings.isNotEmpty)
                  ..._sortReadingsBySequence(
                          _removeDuplicateReadings(_allGlucoseReadings))
                      .map((r) {
                    final color = _glucoseFlagColor(r.flag);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: color,
                            child: Icon(_flagIcon(r.flag),
                                color: Colors.white, size: 18)),
                        title: Text('${r.mgdl.toStringAsFixed(1)} mg/dL'),
                        subtitle: Text(
                            '${r.mmol.toStringAsFixed(2)} mmol/L · ${r.flag}'),
                        trailing: Text(
                            r.timestamp.toString().substring(0, 16),
                            style: const TextStyle(fontSize: 11)),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    if (widget.device != null) BleManager.disconnect(widget.device!);
    super.dispose();
  }
}