import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager {
  // ── Standard service UUIDs ─────────────────────────────────────────────────
  static const String GLUCOSE_SERVICE_UUID = '1808';
  static const String BP_SERVICE_UUID      = '1810';

  // ── Omron custom characteristic UUIDs (HEM-7140T1 proprietary protocol) ───
  // The device does NOT advertise 0x1810. Detection must use device name.
  static const String OMRON_UNLOCK_UUID = 'b305b680-aee7-11e1-a730-0002a5d5c51b';
  static const String OMRON_TX_UUID     = 'db5b55e0-aee7-11e1-965e-0002a5d5c51b';
  static const String OMRON_RX_UUID     = '49123040-aee8-11e1-a74d-0002a5d5c51b';

  // ── Name patterns that identify an Omron BP device ────────────────────────
  // Mirrors the Python: any(k in name.upper() for k in ["BLESMART","HEM","OMRON"])
  static const List<String> _omronNamePatterns = [
    'BLESMART',
    'HEM',
    'OMRON',
  ];

  // ── Detect device type ─────────────────────────────────────────────────────
  /// Port of Python find_device() filter logic.
  /// Checks advertisement service UUIDs first, then device name.
  static String deviceType(ScanResult r) {
    final uuids = r.advertisementData.serviceUuids
        .map((u) => u.toString().toLowerCase())
        .toList();

    // Standard UUID check
    if (uuids.any((u) => u.contains(GLUCOSE_SERVICE_UUID))) return 'Glucose';
    if (uuids.any((u) => u.contains(BP_SERVICE_UUID)))      return 'Blood Pressure';

    // Omron custom UUID check (some firmwares advertise these)
    if (uuids.any((u) =>
        u.contains('b305b680') ||
        u.contains('db5b55e0') ||
        u.contains('49123040'))) return 'Blood Pressure';

    // Name-based fallback — matches Python's name filter exactly
    final name = (r.device.platformName).toUpperCase();
    if (_omronNamePatterns.any((k) => name.contains(k))) return 'Blood Pressure';

    return 'Unknown';
  }

  /// Returns true if a ScanResult is an Omron BP device.
  static bool isOmronDevice(ScanResult r) => deviceType(r) == 'Blood Pressure';

  // ── Scan ───────────────────────────────────────────────────────────────────
  /// Scans and returns results that include glucose OR BP (standard OR Omron).
  /// Mirrors Python find_device(): does NOT restrict by service UUID so that
  /// devices advertising only by name are included.
  static Stream<List<ScanResult>> startScan({
    Duration timeout = const Duration(seconds: 20),
  }) {
    FlutterBluePlus.stopScan();
    FlutterBluePlus.startScan(timeout: timeout);

    return FlutterBluePlus.scanResults.map((results) {
      return results.where((r) {
        final type = deviceType(r);
        return type == 'Glucose' || type == 'Blood Pressure';
      }).toList();
    });
  }

  static Future<void> stopScan() => FlutterBluePlus.stopScan();

  // ── Connect & discover ─────────────────────────────────────────────────────
  static Future<List<BluetoothService>> connectAndDiscover(
      BluetoothDevice device) async {
    print('BleManager: Connecting to ${device.platformName} (${device.remoteId})');
    await device.connect(
      autoConnect: false,
      license: License.free,
    );
    print('BleManager: Connected');
    await Future.delayed(const Duration(milliseconds: 500));
    final services = await device.discoverServices();
    print('BleManager: Discovered ${services.length} services');
    for (final s in services) {
      print('  Service: ${s.uuid}');
    }
    return services;
  }

  static Future<void> disconnect(BluetoothDevice device) =>
      device.disconnect();

  // ── Service finders ────────────────────────────────────────────────────────
  static BluetoothService? findGlucoseService(List<BluetoothService> services) {
    for (final s in services) {
      if (s.uuid.toString().toLowerCase().contains(GLUCOSE_SERVICE_UUID)) {
        return s;
      }
    }
    return null;
  }

  static BluetoothService? findBPService(List<BluetoothService> services) {
    for (final s in services) {
      if (s.uuid.toString().toLowerCase().contains(BP_SERVICE_UUID)) {
        return s;
      }
    }
    return null;
  }

  /// Returns true if the discovered services contain Omron custom characteristics.
  /// Call this after connectAndDiscover() to confirm it's an Omron proprietary device.
  static bool hasOmronCustomServices(List<BluetoothService> services) {
    for (final svc in services) {
      for (final c in svc.characteristics) {
        final u = c.uuid.toString().toLowerCase();
        if (u.contains('b305b680') ||
            u.contains('db5b55e0') ||
            u.contains('49123040')) {
          return true;
        }
      }
    }
    return false;
  }
}