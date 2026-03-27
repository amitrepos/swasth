import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ble/ble_manager.dart';
import 'dashboard_screen.dart';

class ScanScreen extends StatefulWidget {
  final String? deviceType; // 'Glucose', 'Blood Pressure', or 'Armband'
  final int profileId;
  
  const ScanScreen({super.key, this.deviceType, required this.profileId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<ScanResult> _devices = [];
  bool _isScanning = false;
  String _status = 'Press Scan to find your device';

  @override
  void initState() {
    super.initState();
    // Auto-start scan if device type is specified
    if (widget.deviceType != null) {
      _startScan();
    }
  }

  // ── Request BLE permissions then start scan ───────────────────────────────
  Future<void> _startScan() async {
    // Request permissions first
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    setState(() {
      _devices = [];
      _isScanning = true;
      _status = 'Scanning for glucose & BP devices...';
    });

    // Listen to scan results filtered by health service UUIDs
    BleManager.startScan().listen((results) {
      setState(() {
        // Filter by device type if specified
        if (widget.deviceType != null) {
          _devices = results.where((r) {
            final type = BleManager.deviceType(r);
            return type == widget.deviceType;
          }).toList();
        } else {
          _devices = results;
        }
      });
    });

    // Stop scanning after 10 seconds
    await Future.delayed(const Duration(seconds: 10));
    if (mounted) {
      setState(() {
        _isScanning = false;
        _status = _devices.isEmpty
            ? 'No devices found. Make sure device is powered on.'
            : '${_devices.length} ${widget.deviceType ?? 'device'}(s) found';
      });
    }
  }

  // ── Connect to selected device ────────────────────────────────────────────
  Future<void> _connectToDevice(ScanResult result) async {
    await BleManager.stopScan();

    setState(() {
      _status = 'Connecting to ${result.device.platformName}...';
    });

    try {
      final services =
          await BleManager.connectAndDiscover(result.device);

      if (!mounted) return;

      // Navigate to dashboard with device + services
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            device: result.device,
            services: services,
            deviceType: BleManager.deviceType(result),
            profileId: widget.profileId,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _status = 'Connection failed: $e';
      });
    }
  }

  // ── Build device list tile ────────────────────────────────────────────────
  Widget _buildDeviceTile(ScanResult result) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : 'Unknown Device';
    final type = BleManager.deviceType(result);
    final rssi = result.rssi;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: type == 'Glucose' ? Colors.blue : Colors.red,
          child: Icon(
            type == 'Glucose' ? Icons.water_drop : Icons.favorite,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.device.remoteId.toString(),
                style: const TextStyle(fontSize: 12)),
            Text('Type: $type  |  RSSI: $rssi dBm',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _connectToDevice(result),
          child: const Text('Connect'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swasth — Scan Devices'),
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            child: Row(
              children: [
                if (_isScanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_isScanning) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_searching,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Looking for devices...'
                              : 'No devices found yet',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (_, i) => _buildDeviceTile(_devices[i]),
                  ),
          ),
        ],
      ),

      // Scan button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? null : _startScan,
        icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.search),
        label: Text(_isScanning ? 'Scanning...' : 'Scan'),
      ),
    );
  }

  @override
  void dispose() {
    BleManager.stopScan();
    super.dispose();
  }
}
