import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ble/ble_manager.dart';
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
  GlucoseReading? _latestReading;
  List<GlucoseReading> _allReadings = [];
  String _status = 'Requesting records from device...';
  String _racpResponse = '';
  bool _loading = true;
  
  // Device connection states
  bool _glucometerConnected = false;
  bool _bpMeterConnected = false;
  bool _armbandConnected = false;
  
  // Device type tracking
  String _connectedDeviceType = 'Unknown';
  
  // History view state
  bool _showHistoryPanel = false;
  
  // Store discovered services
  List<BluetoothService> _discoveredServices = [];

  @override
  void initState() {
    super.initState();
    if (widget.autoConnect) {
      _startAutoConnect();
    } else if (widget.device != null) {
      _fetchReadings();
    }
  }

  // ── Auto scan and connect to device ───────────────────────────────────────
  Future<void> _startAutoConnect() async {
    String statusMessage = widget.deviceType == 'Blood Pressure' 
        ? 'Scanning for BP meter...' 
        : 'Scanning for glucometer...';
    
    setState(() {
      _status = statusMessage;
      _loading = true;
    });

    try {
      // Request permissions
      await Permission.bluetooth.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await Permission.locationWhenInUse.request();


      // Start scanning
      BleManager.startScan().listen((results) async {
        if (results.isNotEmpty) {
          // Find device based on deviceType
          ScanResult? targetResult;
          
          if (widget.deviceType == 'Blood Pressure') {
            // Find BP device
            final bpResult = results.firstWhere(
              (r) => BleManager.deviceType(r) == 'Blood Pressure',
              orElse: () => results.first,
            );
            targetResult = bpResult;
          } else {
            // Find glucose device (default)
            final glucoseResult = results.firstWhere(
              (r) => BleManager.deviceType(r) == 'Glucose',
              orElse: () => results.first,
            );
            targetResult = glucoseResult;
          }

          _connectToDevice(targetResult);
        }
      });

      // Stop scanning after 10 seconds
      await Future.delayed(const Duration(seconds: 10));
      await BleManager.stopScan();

      if (!_glucometerConnected && !_bpMeterConnected && mounted) {
        setState(() {
          _status = 'No ${widget.deviceType.toLowerCase()} found. Please turn on your device.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Connection error: $e';
          _loading = false;
        });
      }
    }
  }

  // ── Connect to selected device ────────────────────────────────────────────
  Future<void> _connectToDevice(ScanResult result) async {
    await BleManager.stopScan();

    setState(() {
      _status = 'Connecting to ${result.device.platformName}...';
    });

    try {
      final services = await BleManager.connectAndDiscover(result.device);
      final type = BleManager.deviceType(result);

      if (!mounted) return;

      print('Dashboard: Connecting with ${services.length} services, type: $type');
      
      // Store services for later use
      setState(() {
        _discoveredServices = services;
      });

      setState(() {
        _glucometerConnected = type == 'Glucose';
        _bpMeterConnected = type == 'Blood Pressure';
        _armbandConnected = type == 'Unknown'; // For other devices like armband
        _connectedDeviceType = type;
        _loading = false;
      });

      // If glucose device, fetch readings
      if (type == 'Glucose') {
        _fetchReadings();
      } else {
        setState(() {
          _status = 'Connected to $type device';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Connection failed: $e';
          _loading = false;
        });
      }
    }
  }

  // ── Fetch glucose records via RACP flow ───────────────────────────────────
  Future<void> _fetchReadings() async {
    // Use discovered services if widget.services is empty
    final servicesToUse = widget.services.isNotEmpty ? widget.services : _discoveredServices;
    
    if (servicesToUse.isEmpty) {
      setState(() {
        _status = 'No services discovered. Device may not support health data.';
        _loading = false;
      });
      print('Dashboard: No services available');
      return;
    }

    print('Dashboard: Searching for glucose service in ${servicesToUse.length} services...');
    
    // Log all discovered services for debugging
    for (var service in servicesToUse) {
      print('Discovered service: ${service.uuid}');
    }

    final glucoseService = BleManager.findGlucoseService(servicesToUse);

    if (glucoseService == null) {
      setState(() {
        _status = 'Glucose service (0x1808) not found on this device.';
        _loading = false;
      });
      print('Dashboard: Glucose service not found!');
      
      // Show what type of device this might be
      if (_connectedDeviceType == 'Blood Pressure') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This appears to be a BP device, not a glucometer'),
            backgroundColor: AppColors.statusElevated,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device does not support glucose monitoring (0x1808)'),
            backgroundColor: AppColors.statusElevated,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    print('Dashboard: Glucose service found! Fetching records...');
    setState(() => _status = 'Connected. Fetching all stored records...');

    await GlucoseService.requestAllRecords(
      service: glucoseService,
      onReading: (reading) {
        print('Dashboard: Received reading - ${reading.mgdl} mg/dL (Seq: #${reading.sequenceNumber})');
        
        // Save to database
        _saveReadingToDatabase(reading, 'glucose');
        
        setState(() {
          // Remove any existing reading with same sequence number before adding
          _allReadings.removeWhere((r) => r.sequenceNumber == reading.sequenceNumber);
          _allReadings.add(reading);
          _latestReading = reading;
          
          // Show unique count
          final uniqueCount = _removeDuplicateReadings(_allReadings).length;
          _status = 'Received $uniqueCount unique record(s)';
          _loading = false;
        });
      },
      onRacpResponse: (response) {
        print('Dashboard: RACP response - $response');
        setState(() {
          _racpResponse = response;
          _loading = false;
          if (_allReadings.isEmpty) {
            _status = 'RACP: $response';
          }
        });
      },
    );
  }

  // ── Flag color ────────────────────────────────────────────────────────────
  Color _flagColor(String flag) {
    switch (flag) {
      case 'LOW':
        return AppColors.statusElevated;
      case 'NORMAL':
        return AppColors.statusNormal;
      case 'HIGH':
        return AppColors.statusHigh;
      case 'VERY HIGH':
        return AppColors.statusCritical;
      default:
        return AppColors.statusLow;
    }
  }

  // ── Device icon with glow effect ─────────────────────────────────────────
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
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow effect when connected
            if (isConnected)
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            // Icon container
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? color : (isDark ? AppColors.bgPillDark : AppColors.bgPill),
                border: Border.all(
                  color: isConnected ? color : (isDark ? AppColors.bgCard2Dark : AppColors.bgCard2),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: isConnected ? Colors.white : AppColors.textSecondary,
                size: 28,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isConnected ? color : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Remove duplicate readings by sequence number ──────────────────────────
  List<GlucoseReading> _removeDuplicateReadings(List<GlucoseReading> readings) {
    final Map<int, GlucoseReading> uniqueMap = {};
    
    for (var reading in readings) {
      // Use sequence number as key - later occurrences overwrite earlier ones
      uniqueMap[reading.sequenceNumber] = reading;
    }
    
    return uniqueMap.values.toList();
  }

  // ── Sort readings by sequence number (descending - newest first) ─────────
  List<GlucoseReading> _sortReadingsBySequence(List<GlucoseReading> readings) {
    final sorted = List<GlucoseReading>.from(readings);
    sorted.sort((a, b) => b.sequenceNumber.compareTo(a.sequenceNumber));
    return sorted;
  }

  // ── Device selection panel ────────────────────────────────────────────────
  Widget _buildDevicePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Tap to connect a device',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
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
            ],
          ),
        ],
      ),
    );
  }

  // ── Handle device icon tap ────────────────────────────────────────────────
  void _handleDeviceTap(String deviceType) {
    // Check if this device type is already connected
    bool isAlreadyConnected = false;
    
    switch (deviceType) {
      case 'Glucose':
        isAlreadyConnected = _glucometerConnected;
        break;
      case 'Blood Pressure':
        isAlreadyConnected = _bpMeterConnected;
        break;
      case 'Armband':
        isAlreadyConnected = _armbandConnected;
        break;
    }

    // Show confirmation dialog
    String message = isAlreadyConnected
        ? '$_connectedDeviceType is already connected. Do you want to scan for a new $deviceType?'
        : 'Scan for $deviceType?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect $deviceType'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startScanForDevice(deviceType);
            },
            child: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  // ── Scan for specific device type ─────────────────────────────────────────
  Future<void> _startScanForDevice(String deviceType) async {
    setState(() {
      _status = 'Scanning for $deviceType...';
      _loading = true;
    });

    try {
      // Request permissions
      await Permission.bluetooth.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      await Permission.locationWhenInUse.request();

      // Start scanning
      bool deviceFound = false;
      
      BleManager.startScan().listen((results) async {
        if (results.isNotEmpty && !deviceFound) {
          ScanResult? selectedDevice;

          // Find device based on type
          switch (deviceType) {
            case 'Glucose':
              selectedDevice = results.firstWhere(
                (r) => BleManager.deviceType(r) == 'Glucose',
                orElse: () => results.first,
              );
              break;
            case 'Blood Pressure':
              selectedDevice = results.firstWhere(
                (r) => BleManager.deviceType(r) == 'Blood Pressure',
                orElse: () => results.first,
              );
              break;
            default:
              // For armband or other devices, take the first available
              selectedDevice = results.first;
          }

          deviceFound = true;
          _connectToDevice(selectedDevice);
        }
      });

      // Stop scanning after 10 seconds
      await Future.delayed(const Duration(seconds: 10));
      await BleManager.stopScan();

      if (!deviceFound && mounted) {
        setState(() {
          _status = 'No $deviceType found. Please turn on your device.';
          _loading = false;
        });
        
        // Show message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No $deviceType found nearby'),
              backgroundColor: AppColors.statusElevated,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Connection error: $e';
          _loading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.statusCritical,
          ),
        );
      }
    }
  }

  // ── Flag icon ─────────────────────────────────────────────────────────────
  IconData _flagIcon(String flag) {
    switch (flag) {
      case 'LOW':
        return Icons.arrow_downward;
      case 'NORMAL':
        return Icons.check_circle;
      case 'HIGH':
        return Icons.warning;
      case 'VERY HIGH':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }

  // ── Main reading card ─────────────────────────────────────────────────────
  Widget _buildReadingCard(GlucoseReading r) {
    final color = _flagColor(r.flag);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Flag badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_flagIcon(r.flag), color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(r.flag,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Main glucose value
            Text(
              r.mgdl.toStringAsFixed(1),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('mg/dL',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                )),
            const SizedBox(height: 4),
            Text(
              '${r.mmol.toStringAsFixed(2)} mmol/L',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),

            const Divider(height: 32, thickness: 0.5),

            // Details
            _detailRow(Icons.tag, 'Sequence', '#${r.sequenceNumber}'),
            _detailRow(Icons.access_time, 'Time',
                r.timestamp.toString().substring(0, 19)),
            _detailRow(Icons.science, 'Sample Type', r.sampleType),
            _detailRow(Icons.location_on, 'Location', r.sampleLocation),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 8),
          Text('$label: ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  // ── History list ──────────────────────────────────────────────────────────
  Widget _buildHistoryList() {
    // Remove duplicates and sort
    final uniqueReadings = _removeDuplicateReadings(_allReadings);
    final sortedReadings = _sortReadingsBySequence(uniqueReadings);
    
    if (sortedReadings.length <= 1) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('All Records',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${sortedReadings.length} records',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        ...sortedReadings.skip(1).map((r) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _flagColor(r.flag).withOpacity(0.15),
              radius: 20,
              child: Icon(
                _flagIcon(r.flag),
                color: _flagColor(r.flag),
                size: 18,
              ),
            ),
            title: Text(
              '${r.mgdl.toStringAsFixed(1)} mg/dL',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${r.mmol.toStringAsFixed(2)} mmol/L',
                    style: Theme.of(context).textTheme.bodySmall),
                Text(r.timestamp.toString().substring(0, 16),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('#${r.sequenceNumber}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _flagColor(r.flag).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _flagColor(r.flag).withOpacity(0.3), width: 0.5),
                  ),
                  child: Text(
                    r.flag,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _flagColor(r.flag),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  // ── Device-specific history panel ─────────────────────────────────────────
  Widget _buildDeviceHistoryPanel() {
    // Remove duplicates and sort
    final uniqueReadings = _removeDuplicateReadings(_allReadings);
    final sortedReadings = _sortReadingsBySequence(uniqueReadings);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getDeviceIcon(_connectedDeviceType),
                  color: _getDeviceColor(_connectedDeviceType),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_connectedDeviceType History',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_allReadings.length} total records',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showHistoryPanel ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () {
                    setState(() {
                      _showHistoryPanel = !_showHistoryPanel;
                    });
                  },
                ),
              ],
            ),
            if (_showHistoryPanel) ...[
              const Divider(height: 24),
              if (sortedReadings.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 8),
                        Text(
                          'No historical data available',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedReadings.length > 10 ? 10 : sortedReadings.length,
                  itemBuilder: (_, i) {
                    final r = sortedReadings[i];
                    return _buildCompactHistoryTile(r);
                  },
                ),
              if (sortedReadings.length > 10)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showHistoryPanel = false;
                    });
                    _showFullHistoryWithSorted(sortedReadings);
                  },
                  child: const Text('View All History'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Compact history tile ──────────────────────────────────────────────────
  Widget _buildCompactHistoryTile(GlucoseReading r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _flagColor(r.flag),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${r.mgdl.toStringAsFixed(1)} mg/dL',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(
                          (_flagColor(r.flag).r * 255).round().clamp(0, 255),
                          (_flagColor(r.flag).g * 255).round().clamp(0, 255),
                          (_flagColor(r.flag).b * 255).round().clamp(0, 255),
                          0.2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r.flag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _flagColor(r.flag),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.timestamp.toString().substring(0, 16),
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '#${r.sequenceNumber}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Get device icon ───────────────────────────────────────────────────────
  IconData _getDeviceIcon(String type) {
    switch (type) {
      case 'Glucose':
        return Icons.water_drop;
      case 'Blood Pressure':
        return Icons.favorite;
      default:
        return Icons.watch;
    }
  }

  // ── Get device color ──────────────────────────────────────────────────────
  Color _getDeviceColor(String type) {
    switch (type) {
      case 'Glucose':
        return AppColors.glucose;
      case 'Blood Pressure':
        return AppColors.bloodPressure;
      default:
        return AppColors.statusNormal;
    }
  }

  // ── Save reading to database ───────────────────────────────────────────────
  Future<void> _saveReadingToDatabase(dynamic reading, String deviceType) async {
    try {
      print('=== Starting save process ===');
      final token = await StorageService().getToken();
      print('Token retrieved: ${token != null ? "YES" : "NO"}');
      
      if (token == null) {
        print('ERROR: No token found, cannot save reading');
        return;
      }

      print('Converting reading to HealthReading format...');
      final healthReading = HealthReading.fromGlucoseOrBP(reading, deviceType);
      healthReading.profileId = widget.profileId; // Set profile ID
      final readingTimestamp = reading.timestamp ?? DateTime.now();
      print('Created HealthReading: ${healthReading.readingType}, value: ${healthReading.valueNumeric}, profile: ${healthReading.profileId}');
      
      // Check database for existing reading with same timestamp
      print('Checking database for existing readings...');
      final existingReadings = await HealthReadingService().getReadings(
        token: token,
        profileId: widget.profileId,
        limit: 1000,
      );
      
      // Check if any existing reading has the same timestamp
      final isDuplicate = existingReadings.any((existingReading) {
        final existingTime = existingReading.readingTimestamp.millisecondsSinceEpoch;
        final newTime = readingTimestamp.millisecondsSinceEpoch;
        return existingTime == newTime;
      });
      
      if (isDuplicate) {
        print('DUPLICATE: Reading with timestamp $readingTimestamp already exists in database, skipping save');
        return; // Don't save duplicate
      }
      
      print('No duplicate found. Calling API to save reading...');
      final savedReading = await HealthReadingService().saveReading(healthReading, token);
      print('SUCCESS: Reading saved with ID: ${savedReading.id}');
      
      // Add to local list after successful save
      setState(() {
        if (reading is GlucoseReading) {
          _allReadings.add(reading);
          _latestReading = reading;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${deviceType == 'glucose' ? 'Glucose' : 'BP'} saved: ${healthReading.displayValue}'),
            backgroundColor: AppColors.statusNormal,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('ERROR saving reading: $e');
      print('Stack trace: $stackTrace');
      // Don't show error to user - reading was still displayed
    }
  }

  // ── Show full history dialog ──────────────────────────────────────────────
  void _showFullHistory() {
    // Remove duplicates and sort
    final uniqueReadings = _removeDuplicateReadings(_allReadings);
    final sortedReadings = _sortReadingsBySequence(uniqueReadings);
    _showFullHistoryWithSorted(sortedReadings);
  }

  // ── Show full history with sorted data ────────────────────────────────────
  void _showFullHistoryWithSorted(List<GlucoseReading> sortedReadings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_getDeviceIcon(_connectedDeviceType), color: _getDeviceColor(_connectedDeviceType)),
                  const SizedBox(width: 8),
                  Text(
                    'All $_connectedDeviceType Records',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedReadings.length,
                itemBuilder: (_, i) {
                  final r = sortedReadings[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _flagColor(r.flag),
                        child: Icon(_flagIcon(r.flag), color: Colors.white, size: 18),
                      ),
                      title: Text('${r.mgdl.toStringAsFixed(1)} mg/dL'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.mmol.toStringAsFixed(2)} mmol/L'),
                          const SizedBox(height: 4),
                          Text(r.timestamp.toString().substring(0, 16),
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text('Sample: ${r.sampleType} | Location: ${r.sampleLocation}',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('#${r.sequenceNumber}',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(
                                (_flagColor(r.flag).r * 255).round().clamp(0, 255),
                                (_flagColor(r.flag).g * 255).round().clamp(0, 255),
                                (_flagColor(r.flag).b * 255).round().clamp(0, 255),
                                0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _flagColor(r.flag), width: 0.5),
                            ),
                            child: Text(
                              r.flag,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _flagColor(r.flag),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = widget.device?.platformName.isNotEmpty == true
        ? widget.device!.platformName
        : 'Swasth Health Monitor';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName),
        actions: [
          if (widget.device != null) ...[
            if (_allReadings.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: _showFullHistory,
                tooltip: 'View All History',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _allReadings = [];
                  _latestReading = null;
                  _loading = true;
                  _status = 'Refreshing...';
                });
                _fetchReadings();
              },
            ),
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: () {
                final device = widget.device;
                if (device != null) {
                  BleManager.disconnect(device).then((_) {
                    if (!mounted) return;
                    setState(() {
                      _glucometerConnected = false;
                      _bpMeterConnected = false;
                      _armbandConnected = false;
                      _connectedDeviceType = 'Unknown';
                      _allReadings = [];
                      _latestReading = null;
                      _status = 'Disconnected';
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Device disconnected'),
                        ),
                      );
                    });
                  });
                }
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Device connection panel
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildDevicePanel(),
            ),

            // Status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? AppColors.insight.withOpacity(0.1) : AppColors.insight.withOpacity(0.05),
              child: Row(
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (_loading) const SizedBox(width: 8),
                  Expanded(
                      child: Text(_status,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.insight,
                            fontWeight: FontWeight.w500,
                          ))),
                ],
              ),
            ),

            // Loading state
            if (_loading && _latestReading == null)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Fetching glucose records...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),

            // Latest reading card
            if (_latestReading != null) _buildReadingCard(_latestReading!),

            // Device history panel
            if (widget.device != null && _allReadings.isNotEmpty)
              _buildDeviceHistoryPanel(),

            // RACP response
            if (_racpResponse.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Device response: $_racpResponse',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
              ),

            // History list (shown when not using the new panel)
            if (!_showHistoryPanel) _buildHistoryList(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (widget.device != null) {
      BleManager.disconnect(widget.device!);
    }
    super.dispose();
  }
}