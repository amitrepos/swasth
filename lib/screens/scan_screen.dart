import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import '../services/api_exception.dart';
import '../services/error_mapper.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
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
  // '' means show the default "press scan" message from l10n
  String _status = '';

  @override
  void initState() {
    super.initState();
    if (widget.deviceType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
    }
  }

  Future<void> _startScan() async {
    final l10n = AppLocalizations.of(context)!;

    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();

    setState(() {
      _devices = [];
      _isScanning = true;
      _status = l10n.lookingForDevices;
    });

    BleManager.startScan().listen((results) {
      setState(() {
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

    await Future.delayed(const Duration(seconds: 10));
    if (mounted) {
      final l10nAfter = AppLocalizations.of(context)!;
      setState(() {
        _isScanning = false;
        _status = _devices.isEmpty
            ? l10nAfter.noDevicesFoundAfterScan
            : '${_devices.length} ${widget.deviceType ?? 'device'}(s) found';
      });
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    await BleManager.stopScan();

    setState(() {
      _status = 'Connecting to ${result.device.platformName}...';
    });

    try {
      final services = await BleManager.connectAndDiscover(result.device);

      if (!mounted) return;

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
      if (!mounted) return;
      if (e is UnauthorizedException) {
        await ErrorMapper.showSnack(context, e);
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _status = ErrorMapper.userMessage(l10n, e);
      });
    }
  }

  Widget _buildDeviceTile(ScanResult result) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : 'Unknown Device';
    final type = BleManager.deviceType(result);
    final rssi = result.rssi;
    final l10n = AppLocalizations.of(context)!;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      borderRadius: 16,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: type == 'Glucose'
              ? AppColors.glucose
              : AppColors.bloodPressure,
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
            Text(
              result.device.remoteId.toString(),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Type: $type  |  RSSI: $rssi dBm',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _connectToDevice(result),
          child: Text(l10n.connectButton),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayStatus = _status.isEmpty ? l10n.pressScanToFind : _status;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanDevicesTitle)),
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
                    displayStatus,
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
                        Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? l10n.lookingForDevices
                              : l10n.noDevicesFound,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
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

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? null : _startScan,
        icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.search),
        label: Text(_isScanning ? l10n.scanningButton : l10n.scanButton),
      ),
    );
  }

  @override
  void dispose() {
    BleManager.stopScan();
    super.dispose();
  }
}
