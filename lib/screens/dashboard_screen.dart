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
    } else {
      // No device and no auto-connect - let user tap device panel to connect
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          setState(() {
            _loading = false;
            _status = l10n.tapDeviceToConnect;
          });
        }
      });
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
      
      // Scan for devices matching the widget.deviceType
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
        
        // Clear readings from OTHER device types to avoid confusion
        // Only keep readings that match the currently connected device
        if (type == 'Glucose') {
          // Connected to glucose - clear BP readings from display
          _latestBPReading = null;
          _allBPReadings = [];
        } else if (type == 'Blood Pressure') {
          // Connected to BP - clear glucose readings from display
          _latestGlucoseReading = null;
          _allGlucoseReadings = [];
        }
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
    // Show device selection dialog
    await _showDeviceSelectionDialog(deviceType);
  }

  Future<void> _showDeviceSelectionDialog(String deviceType) async {
    // Request permissions first
    try {
      await _requestPermissions();
      
      // Check if permissions were granted
      final bleStatus = await FlutterBluePlus.adapterState.first;
      if (bleStatus != BluetoothAdapterState.on) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bluetooth is not enabled. Please enable Bluetooth and try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // Show loading dialog
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _DeviceSelectionDialog(
          deviceType: deviceType,
          onDeviceSelected: (device) {
            Navigator.pop(dialogContext);
            _connectToDevice(device);
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Save helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveBPReading(BPReading reading) async {
    try {
      final token = await StorageService().getToken();
      if (token == null) return;

      // Convert BPReading to HealthReading and save to database
      final healthReading = HealthReading.fromGlucoseOrBP(reading, 'blood_pressure');
      healthReading.profileId = widget.profileId;

      // Save to database (backend will handle deduplication via seq)
      final saveResult = await HealthReadingService().saveReading(healthReading, token);
      
      // Check if backend skipped this as a duplicate
      if (saveResult['skipped'] == true) {
        print('BP reading skipped by backend (duplicate seq: ${healthReading.seq})');
        return;
      }

      final saved = saveResult['reading'] as HealthReading;
      print('BP reading saved successfully - ID: ${saved.id}, seq: ${saved.seq}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('BP Saved: ${healthReading.displayValue}'),
          backgroundColor: AppColors.statusNormal,
          duration: const Duration(seconds: 2),
        ));
      }
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

      // For BLE readings with sequence numbers, let backend handle deduplication
      // For manual readings (no seq), use timestamp-based deduplication
      if (healthReading.seq == null) {
        final existingReadings = await HealthReadingService().getReadings(
          token: token,
          profileId: widget.profileId,
          limit: 1000,
        );

        final isDuplicate = existingReadings.any((e) =>
            e.readingTimestamp.millisecondsSinceEpoch ==
            readingTimestamp.millisecondsSinceEpoch);

        if (isDuplicate) {
          print('Duplicate reading detected (timestamp), skipping save');
          return;
        }
      }

      final saveResult =
          await HealthReadingService().saveReading(healthReading, token);
      
      // Check if backend skipped this as a duplicate
      if (saveResult['skipped'] == true) {
        print('Reading skipped by backend (duplicate seq: ${healthReading.seq})');
        return;
      }

      final saved = saveResult['reading'] as HealthReading;
      print('Saved reading ID: ${saved.id}, seq: ${saved.seq}');

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
    final l10n = AppLocalizations.of(context)!;
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
          child: Text(l10n.tapToConnectDevice,
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
    final l10n = AppLocalizations.of(context)!;
    final isConnected = deviceType == 'Glucose'
        ? _glucometerConnected
        : deviceType == 'Blood Pressure'
            ? _bpMeterConnected
            : _armbandConnected;

    final message = isConnected
        ? l10n.alreadyConnectedMessage(deviceType)
        : l10n.scanForDeviceMessage(deviceType);

    // Extra hint for Omron users
    final hint = deviceType == 'Blood Pressure' ? l10n.bpTransferHint : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.connectDeviceType(deviceType)),
        content: Text('$message$hint'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _startScanForDevice(deviceType);
              },
              child: Text(l10n.scan)),
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
    final l10n = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text(l10n.bpHistory,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(l10n.recordsCount(_allBPReadings.length),
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
    final l10n = AppLocalizations.of(context)!;
    final unique = _removeDuplicateReadings(_allGlucoseReadings);
    final sorted = _sortReadingsBySequence(unique);
    if (sorted.length <= 1) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text(l10n.allRecords,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(l10n.recordsCount(sorted.length),
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
    final l10n = AppLocalizations.of(context)!;
    final deviceName = widget.device?.platformName.isNotEmpty == true
        ? widget.device!.platformName
        : 'Swasth Health Monitor';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final showBPCard     = _latestBPReading != null && _connectedDeviceType == 'Blood Pressure';
    final showGlucCard   = _latestGlucoseReading != null && _connectedDeviceType == 'Glucose';
    final showBPHistory  = _allBPReadings.isNotEmpty && _connectedDeviceType == 'Blood Pressure';
    final showGlucHistory= _allGlucoseReadings.isNotEmpty && _connectedDeviceType == 'Glucose';

    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName),
        actions: [
          if (_allBPReadings.isNotEmpty || _allGlucoseReadings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showFullHistory,
              tooltip: l10n.viewAllHistory,
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
                      SnackBar(content: Text(l10n.deviceDisconnected)));
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
    final l10n = AppLocalizations.of(context)!;
    final historyTitle = _connectedDeviceType == 'Blood Pressure' 
        ? l10n.bpHistory 
        : _connectedDeviceType == 'Glucose' 
            ? l10n.allRecords 
            : '$_connectedDeviceType Records';
    
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
              Text(historyTitle,
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
                if (_connectedDeviceType == 'Blood Pressure' && _allBPReadings.isNotEmpty)
                  ..._allBPReadings.map((r) {
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
                if (_connectedDeviceType == 'Glucose' && _allGlucoseReadings.isNotEmpty)
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

// ═══════════════════════════════════════════════════════════════════════════
// Device Selection Dialog Widget
// ═══════════════════════════════════════════════════════════════════════════

class _DeviceSelectionDialog extends StatefulWidget {
  final String deviceType;
  final Function(ScanResult) onDeviceSelected;

  const _DeviceSelectionDialog({
    required this.deviceType,
    required this.onDeviceSelected,
  });

  @override
  State<_DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<_DeviceSelectionDialog> {
  List<ScanResult> _devices = [];
  bool _isScanning = true;
  int _scanGeneration = 0; // Track scan sessions to avoid race conditions

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  void _startScanning() {
    final currentGeneration = ++_scanGeneration;
    
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    // Start scan with shorter timeout for faster results
    final subscription = BleManager.startScan(timeout: const Duration(seconds: 10)).listen((results) {
      if (mounted && currentGeneration == _scanGeneration) {
        setState(() {
          // Filter devices based on type
          _devices = results.where((r) {
            if (widget.deviceType == 'Glucose') {
              return BleManager.deviceType(r) == 'Glucose';
            } else if (widget.deviceType == 'Blood Pressure') {
              return BleManager.deviceType(r) == 'Blood Pressure';
            }
            return true; // For armband or other types - show all
          }).toList();
          // Device list updates in real-time as scan results come in
        });
      }
    });

    // Auto-stop scanning after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && currentGeneration == _scanGeneration) {
        BleManager.stopScan();
        subscription.cancel();
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  void _rescan() {
    // Increment generation to invalidate previous scan callbacks
    _scanGeneration++;
    BleManager.stopScan();
    _startScanning();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.selectDevice),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show device-specific instructions
            _buildInstructionsCard(),
            const SizedBox(height: 12),
            if (_isScanning)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for devices...'),
                ],
              )
            else if (_devices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noDevicesFound, textAlign: TextAlign.center),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  itemBuilder: (ctx, index) {
                    final device = _devices[index];
                    final name = device.device.platformName.isNotEmpty
                        ? device.device.platformName
                        : l10n.unknownDevice;
                    
                    return ListTile(
                      leading: Icon(
                        widget.deviceType == 'Glucose' ? Icons.water_drop : Icons.favorite,
                        color: widget.deviceType == 'Glucose' ? AppColors.glucose : AppColors.bloodPressure,
                      ),
                      title: Text(name),
                      subtitle: Text(l10n.signalStrength(device.rssi)),
                      onTap: () {
                        widget.onDeviceSelected(device);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            BleManager.stopScan();
            Navigator.pop(context);
          },
          child: Text(l10n.cancel),
        ),
        if (!_isScanning)
          TextButton(
            onPressed: _rescan,
            child: Text(l10n.rescan),
          ),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    final isGlucose = widget.deviceType == 'Glucose';
    
    return Card(
      color: (isGlucose ? AppColors.glucose : AppColors.bloodPressure).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isGlucose ? AppColors.glucose : AppColors.bloodPressure,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isGlucose ? 'Glucometer – Prerequisites:' : 'BP Meter – Prerequisites:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isGlucose ? AppColors.glucose : AppColors.bloodPressure,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isGlucose) ...[
              const Text(
                'For the first time:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                '1. Pair the device via Bluetooth. The glucometer will display "OK" once connected.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 8),
              const Text(
                'Always:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                '2. Take a sugar test, or press the bottom-right button to view history on the device screen.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 4),
              const Text(
                '3. The app will scan and display the current reading or history.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
            ] else ...[
              const Text(
                'For the first time:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                '1. Press and hold the Bluetooth button on the Omron HEM-7140T1 until \'P\' starts blinking.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 4),
              const Text(
                '2. Pair the device manually via Bluetooth. After pairing, \'P\' will continue blinking.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 4),
              const Text(
                '3. Click the \' + \' icon. The device will display "OK", and the app will show readings.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 8),
              const Text(
                'Always:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                '4. Click the \' + \' icon. The app will scan and display current and previous readings.',
                style: TextStyle(fontSize: 11, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    BleManager.stopScan();
    super.dispose();
  }
}