import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager {
  static const String GLUCOSE_SERVICE_UUID = '1808';
  static const String BP_SERVICE_UUID = '1810';

  // ── Scan for health devices ───────────────────────────────────────────────
  // Port of Python find_glucometer() — filters by service UUID instead of name
  static Stream<List<ScanResult>> startScan() {
    // Stop any existing scan first
    FlutterBluePlus.stopScan();

    // Start fresh scan for 10 seconds
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // Return filtered stream — only glucose or BP devices
    return FlutterBluePlus.scanResults.map((results) {
      return results.where((r) {
        final uuids = r.advertisementData.serviceUuids
            .map((u) => u.toString().toLowerCase())
            .toList();
        return uuids.any((u) =>
            u.contains(GLUCOSE_SERVICE_UUID) ||
            u.contains(BP_SERVICE_UUID));
      }).toList();
    });
  }

  static Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // ── Connect and discover services ────────────────────────────────────────
  static Future<List<BluetoothService>> connectAndDiscover(
      BluetoothDevice device) async {
    print('BLE Manager: Connecting to device ${device.platformName} (${device.remoteId})');
    
    await device.connect(autoConnect: false);
    print('BLE Manager: Connected successfully');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    print('BLE Manager: Discovering services...');
    final services = await device.discoverServices();
    print('BLE Manager: Discovered ${services.length} services');
    
    for (var service in services) {
      print('  - Service: ${service.uuid}');
    }
    
    return services;
  }

  // ── Disconnect ───────────────────────────────────────────────────────────
  static Future<void> disconnect(BluetoothDevice device) async {
    await device.disconnect();
  }

  // ── Find Glucose service within discovered services ───────────────────────
  // Same as Python find_handles() — searches within 0x1808 service only
  static BluetoothService? findGlucoseService(
      List<BluetoothService> services) {
    print('BLE Manager: Looking for glucose service in ${services.length} services');
    
    for (BluetoothService s in services) {
      String uuid = s.uuid.toString().toLowerCase();
      print('  Checking service: $uuid');
      
      if (uuid.contains(GLUCOSE_SERVICE_UUID)) {
        print('  ✓ Found glucose service: ${s.uuid}');
        return s;
      }
    }
    
    print('  ✗ Glucose service (0x1808) not found');
    return null;
  }

  // ── Find BP service within discovered services ────────────────────────────
  static BluetoothService? findBPService(List<BluetoothService> services) {
    for (BluetoothService s in services) {
      if (s.uuid.toString().toLowerCase().contains(BP_SERVICE_UUID)) {
        return s;
      }
    }
    return null;
  }

  // ── Check device type from advertisement data ─────────────────────────────
  static String deviceType(ScanResult r) {
    final uuids = r.advertisementData.serviceUuids
        .map((u) => u.toString().toLowerCase())
        .toList();
    if (uuids.any((u) => u.contains(GLUCOSE_SERVICE_UUID))) return 'Glucose';
    if (uuids.any((u) => u.contains(BP_SERVICE_UUID))) return 'Blood Pressure';
    return 'Unknown';
  }
}