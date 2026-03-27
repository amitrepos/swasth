import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Blood Pressure Reading Model
class BPReading {
  final double systolic;              // Top number (mmHg or kPa)
  final double diastolic;             // Bottom number (mmHg or kPa)
  final double meanArterialPressure;  // MAP - average pressure
  final double pulseRate;             // Heart rate (bpm)
  final String unit;                  // 'mmHg' or 'kPa'
  final String flag;                  // Blood pressure category
  final DateTime? timestamp;          // Measurement time

  BPReading({
    required this.systolic,
    required this.diastolic,
    required this.meanArterialPressure,
    required this.pulseRate,
    required this.unit,
    required this.flag,
    this.timestamp,
  });

  /// Get blood pressure status description
  String get statusDescription {
    switch (flag) {
      case 'NORMAL':
        return 'Normal - Healthy blood pressure';
      case 'ELEVATED':
        return 'Elevated - Slightly high';
      case 'HIGH - STAGE 1':
        return 'High Stage 1 - Consult doctor';
      case 'HIGH - STAGE 2':
        return 'High Stage 2 - Medical attention needed';
      default:
        return 'Unknown';
    }
  }

  @override
  String toString() {
    return 'BPReading(${systolic.toStringAsFixed(0)}/'
        '${diastolic.toStringAsFixed(0)} $unit, '
        'pulse: ${pulseRate.toStringAsFixed(0)} bpm, '
        'status: $flag)';
  }
}

/// Blood Pressure Service for Omron HEM-7140T and similar devices
class BPService {
  // ── Bluetooth UUIDs ────────────────────────────────────────────────────────
  
  /// Blood Pressure Service UUID (Standard)
  static const String BP_SERVICE_UUID = '1810';
  
  /// Blood Pressure Measurement Characteristic (INDICATE)
  static const String BP_MEASUREMENT_UUID = '2a35';
  
  /// Intermediate Cuff Pressure Characteristic (NOTIFY) - Live cuff pressure
  static const String INTERMEDIATE_CUFF_UUID = '2a36';
  
  /// Blood Pressure Feature Characteristic (READ)
  static const String BP_FEATURE_UUID = '2a49';

  // ── SFLOAT Decoder ─────────────────────────────────────────────────────────
  
  /// Decode IEEE 11073-20601 SFLOAT format
  /// Used by Bluetooth health devices for compact float representation
  static double decodeSFloat(int raw) {
    int mantissa = raw & 0x0FFF;
    if (mantissa >= 0x0800) mantissa -= 0x1000;
    int exponent = (raw >> 12) & 0x0F;
    if (exponent >= 0x08) exponent -= 0x10;
    return mantissa * pow(10.0, exponent).toDouble();
  }

  // ── Blood Pressure Classification ──────────────────────────────────────────
  
  /// Classify blood pressure according to AHA guidelines
  static String bpFlag(double systolic, double diastolic) {
    if (systolic < 120 && diastolic < 80) return 'NORMAL';
    if (systolic < 130 && diastolic < 80) return 'ELEVATED';
    if (systolic < 140 || diastolic < 90) return 'HIGH - STAGE 1';
    return 'HIGH - STAGE 2';
  }

  /// Get color code for BP status
  static String getStatusColor(String flag) {
    switch (flag) {
      case 'NORMAL':
        return 'green';
      case 'ELEVATED':
        return 'yellow';
      case 'HIGH - STAGE 1':
        return 'orange';
      case 'HIGH - STAGE 2':
        return 'red';
      default:
        return 'grey';
    }
  }

  // ── Packet Decoder ─────────────────────────────────────────────────────────
  
  /// Decodes 0x2A35 Blood Pressure Measurement characteristic
  /// 
  /// Byte layout:
  /// - Byte 0     : Flags
  /// - Bytes 1-2  : Systolic (SFLOAT)
  /// - Bytes 3-4  : Diastolic (SFLOAT)
  /// - Bytes 5-6  : Mean Arterial Pressure (SFLOAT)
  /// - Bytes 7-13 : Timestamp (if flag bit 1 set)
  /// - Bytes 14-15: Pulse Rate (SFLOAT, if flag bit 2 set)
  /// - Additional : User ID, Status flags if present
  static BPReading? decodePacket(List<int> data) {
    try {
      if (data.length < 7) {
        print('BPService: Packet too short (${data.length} bytes)');
        return null;
      }

      int flags = data[0];

      // Units: bit 0 = 0 → mmHg, 1 → kPa
      String unit = (flags & 0x01) == 1 ? 'kPa' : 'mmHg';

      // Decode main readings
      double systolic = decodeSFloat(data[1] | (data[2] << 8));
      double diastolic = decodeSFloat(data[3] | (data[4] << 8));
      double map = decodeSFloat(data[5] | (data[6] << 8));

      int idx = 7;

      // Bit 1: Timestamp present
      DateTime? timestamp;
      if ((flags & 0x02) != 0 && data.length >= idx + 7) {
        int year = data[idx] | (data[idx + 1] << 8);
        idx += 2;
        int month = data[idx++];
        int day = data[idx++];
        int hour = data[idx++];
        int minute = data[idx++];
        int second = data[idx++];
        timestamp = DateTime(year, month, day, hour, minute, second);
      }

      // Bit 2: Pulse rate present
      double pulse = 0;
      if ((flags & 0x04) != 0 && data.length >= idx + 2) {
        pulse = decodeSFloat(data[idx] | (data[idx + 1] << 8));
        idx += 2;
      }

      // Bit 3: User ID present
      if ((flags & 0x08) != 0) idx += 1;

      // Bit 4: Measurement status present
      if ((flags & 0x10) != 0 && data.length >= idx + 2) {
        int status = data[idx] | (data[idx + 1] << 8);
        if (status != 0) {
          // Log sensor warnings
          _logMeasurementWarnings(status);
        }
      }

      // Validate readings
      if (!_isValidReading(systolic, diastolic, pulse)) {
        print('BPService: Invalid reading values');
        return null;
      }

      return BPReading(
        systolic: systolic,
        diastolic: diastolic,
        meanArterialPressure: map,
        pulseRate: pulse,
        unit: unit,
        flag: bpFlag(systolic, diastolic),
        timestamp: timestamp ?? DateTime.now(),
      );
    } catch (e) {
      print('BPService.decodePacket error: $e');
      return null;
    }
  }

  /// Log measurement warning flags
  static void _logMeasurementWarnings(int status) {
    if ((status & 0x0001) != 0) print('⚠️ BP Warning: Body movement detected');
    if ((status & 0x0002) != 0) print('⚠️ BP Warning: Cuff too loose');
    if ((status & 0x0004) != 0) print('⚠️ BP Warning: Irregular pulse');
    if ((status & 0x0008) != 0) print('⚠️ BP Warning: Cuff wrapped incorrectly');
    if ((status & 0x0010) != 0) print('⚠️ BP Warning: Measurement out of range');
    if ((status & 0x0020) != 0) print('⚠️ BP Warning: Improper measurement position');
  }

  /// Validate BP reading ranges
  static bool _isValidReading(double systolic, double diastolic, double pulse) {
    // Check for reasonable BP ranges
    if (systolic < 50 || systolic > 250) return false;
    if (diastolic < 30 || diastolic > 150) return false;
    if (pulse < 30 || pulse > 200) return false;
    
    // Diastolic should be less than systolic
    if (diastolic >= systolic) return false;
    
    return true;
  }

  // ── Subscribe to BP Measurement ────────────────────────────────────────────
  
  /// Subscribe to Blood Pressure measurements
  /// 
  /// For Omron HEM-7140T1:
  /// - No RACP (Record Access Control Point) needed
  /// - Just subscribe to 0x2A35 (indicate)
  /// - Take a measurement on the device → reading is pushed automatically
  static Future<void> subscribeToBPMeasurement({
    required BluetoothService service,
    required Function(BPReading) onReading,
    Function(double)? onCuffPressure, // Optional live cuff pressure callback
    Function(String)? onError,
  }) async {
    BluetoothCharacteristic? bpMeasurement;
    BluetoothCharacteristic? intermediateCuff;

    // Find characteristics
    for (BluetoothCharacteristic c in service.characteristics) {
      String uuid = c.uuid.toString().toLowerCase();
      if (uuid.contains(BP_MEASUREMENT_UUID)) bpMeasurement = c;
      if (uuid.contains(INTERMEDIATE_CUFF_UUID)) intermediateCuff = c;
    }

    if (bpMeasurement == null) {
      throw Exception('BP Measurement characteristic not found');
    }

    print('🩺 BPService: Found BP Measurement characteristic');

    // Subscribe to BP Measurement indications (0x2A35)
    try {
      await bpMeasurement.setNotifyValue(true);
      print('✅ BPService: Notifications enabled for BP Measurement');
    } catch (e) {
      onError?.call('Failed to enable BP notifications: $e');
      rethrow;
    }

    // Listen for BP readings
    bpMeasurement.onValueReceived.listen((value) {
      print('[BP] Raw hex: ${_bytesToHex(value)}');
      final reading = decodePacket(value);
      if (reading != null) {
        print('✓ $reading');
        onReading(reading);
      } else {
        print('✗ Failed to decode BP packet');
      }
    });

    // Subscribe to intermediate cuff pressure if available (optional)
    if (intermediateCuff != null && onCuffPressure != null) {
      try {
        await intermediateCuff.setNotifyValue(true);
        intermediateCuff.onValueReceived.listen((value) {
          if (value.length >= 3) {
            final cuffPressure = decodeSFloat(value[1] | (value[2] << 8));
            onCuffPressure(cuffPressure);
          }
        });
        print('✅ BPService: Intermediate cuff pressure subscribed');
      } catch (e) {
        print('ℹ️ BPService: No intermediate cuff pressure available');
      }
    }

    print('🎯 BPService: Ready — take a measurement on the BP device');
  }

  /// Unsubscribe from BP measurements
  static Future<void> unsubscribeFromBPMeasurement({
    required BluetoothService service,
  }) async {
    for (BluetoothCharacteristic c in service.characteristics) {
      String uuid = c.uuid.toString().toLowerCase();
      if (uuid.contains(BP_MEASUREMENT_UUID)) {
        try {
          await c.setNotifyValue(false);
          print('✅ BPService: Unsubscribed from BP measurements');
        } catch (e) {
          print('⚠️ BPService: Error unsubscribing: $e');
        }
      }
    }
  }

  /// Read BP feature flags
  static Future<int?> readBPFeatures({
    required BluetoothService service,
  }) async {
    BluetoothCharacteristic? featureChar;

    for (BluetoothCharacteristic c in service.characteristics) {
      String uuid = c.uuid.toString().toLowerCase();
      if (uuid.contains(BP_FEATURE_UUID)) {
        featureChar = c;
        break;
      }
    }

    if (featureChar == null) {
      print('ℹ️ BPService: Feature characteristic not found');
      return null;
    }

    try {
      List<int> value = await featureChar.read();
      if (value.isNotEmpty) {
        int features = value[0];
        print('📋 BP Features: 0x${features.toRadixString(16).padLeft(2, "0")}');
        
        // Decode feature flags
        if ((features & 0x01) != 0) print('  - Body movement detection supported');
        if ((features & 0x02) != 0) print('  - Cuff fit detection supported');
        if ((features & 0x04) != 0) print('  - Irregular pulse detection supported');
        if ((features & 0x08) != 0) print('  - Pulse rate range detection supported');
        if ((features & 0x10) != 0) print('  - Measurement position detection supported');
        
        return features;
      }
    } catch (e) {
      print('⚠️ BPService: Failed to read features: $e');
    }
    
    return null;
  }

  // ── Helper Methods ─────────────────────────────────────────────────────────
  
  /// Convert bytes to hex string for debugging
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  // Note: isBPDevice() and findBPService() are in ble_manager.dart
}