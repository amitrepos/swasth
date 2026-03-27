import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/glucose_reading.dart';

class GlucoseService {
  static const String GLUCOSE_SERVICE_UUID = '1808';
  static const String GLUCOSE_MEASUREMENT_UUID = '2a18';
  static const String RACP_UUID = '2a52';

  // ── SFLOAT decoder (same logic as Python decode_sfloat) ──────────────────
  static double decodeSFloat(int raw) {
    int mantissa = raw & 0x0FFF;
    if (mantissa >= 0x0800) mantissa -= 0x1000; // signed 12-bit
    int exponent = (raw >> 12) & 0x0F;
    if (exponent >= 0x08) exponent -= 0x10; // signed 4-bit
    return mantissa * pow(10.0, exponent).toDouble();
  }

  // ── Sample type lookup ───────────────────────────────────────────────────
  static String sampleType(int val) {
    const types = {
      1: 'Capillary whole blood',
      2: 'Capillary plasma',
      3: 'Venous whole blood',
      4: 'Venous plasma',
      5: 'Arterial whole blood',
      6: 'Arterial plasma',
      7: 'Undetermined whole blood',
      8: 'Undetermined plasma',
      9: 'Interstitial fluid',
      10: 'Control solution',
    };
    return types[val] ?? 'Unknown ($val)';
  }

  // ── Sample location lookup ───────────────────────────────────────────────
  static String sampleLocation(int val) {
    const locations = {
      1: 'Finger',
      2: 'Alternate site',
      3: 'Earlobe',
      4: 'Control solution',
      15: 'Not available',
    };
    return locations[val] ?? 'Unknown ($val)';
  }

  // ── Glucose flag ─────────────────────────────────────────────────────────
  static String glucoseFlag(double mgdl) {
    if (mgdl < 70) return 'LOW';
    if (mgdl <= 140) return 'NORMAL';
    if (mgdl <= 180) return 'HIGH';
    return 'VERY HIGH';
  }

  // ── Packet decoder (port of Python decode_glucose) ───────────────────────
  static GlucoseReading? decodePacket(List<int> data) {
    try {
      if (data.length < 10) return null;

      int flags  = data[0];
      int seq    = data[1] | (data[2] << 8);
      int year   = data[3] | (data[4] << 8);
      int month  = data[5];
      int day    = data[6];
      int hour   = data[7];
      int minute = data[8];
      int second = data[9];

      DateTime baseTime = DateTime(year, month, day, hour, minute, second);
      int idx = 10;

      // Bit 0: Time offset present (signed int16, minutes)
      int offsetMinutes = 0;
      if (flags & 0x01 != 0) {
        int raw = data[idx] | (data[idx + 1] << 8);
        offsetMinutes = raw > 0x7FFF ? raw - 0x10000 : raw;
        idx += 2;
      }
      DateTime actualTime = baseTime.add(Duration(minutes: offsetMinutes));

      // Bit 1: Glucose concentration present
      double mgdl = 0;
      String type = 'Unknown';
      String location = 'Unknown';

      if (flags & 0x02 != 0) {
        int rawGlucose = data[idx] | (data[idx + 1] << 8);
        idx += 2;
        double concentration = decodeSFloat(rawGlucose);

        // Bit 2: units — 0 = kg/L, 1 = mol/L
        if (flags & 0x04 != 0) {
          mgdl = concentration * 1000 * 180.16 * 10; // mol/L to mg/dL
        } else {
          mgdl = concentration * 100000; // kg/L to mg/dL
        }

        int typeLoc = data[idx];
        idx += 1;
        type = sampleType(typeLoc & 0x0F);
        location = sampleLocation((typeLoc >> 4) & 0x0F);
      }

      return GlucoseReading(
        sequenceNumber: seq,
        timestamp: actualTime,
        mgdl: mgdl,
        mmol: mgdl / 18.016,
        flag: glucoseFlag(mgdl),
        sampleType: type,
        sampleLocation: location,
      );
    } catch (e) {
      print('GlucoseService.decodePacket error: $e');
      return null;
    }
  }

  // ── RACP flow (port of Python main RACP steps) ───────────────────────────
  // Step 1: enable notifications on 0x2A18
  // Step 2: enable indications on 0x2A52
  // Step 3: write 0x0101 to 0x2A52
  static Future<void> requestAllRecords({
    required BluetoothService service,
    required Function(GlucoseReading) onReading,
    required Function(String) onRacpResponse,
  }) async {
    BluetoothCharacteristic? measurement;
    BluetoothCharacteristic? racp;

    // Find characteristics within Glucose service only (avoids UUID ambiguity)
    for (BluetoothCharacteristic c in service.characteristics) {
      String uuid = c.uuid.toString().toLowerCase();
      if (uuid.contains(GLUCOSE_MEASUREMENT_UUID)) measurement = c;
      if (uuid.contains(RACP_UUID)) racp = c;
    }

    if (measurement == null || racp == null) {
      print('GlucoseService: Could not find required characteristics');
      return;
    }

    // Step 1: Enable notifications on Glucose Measurement
    await measurement.setNotifyValue(true);
    measurement.onValueReceived.listen((value) {
      final reading = decodePacket(value);
      if (reading != null) onReading(reading);
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Step 2: Enable indications on RACP
    await racp.setNotifyValue(true);
    racp.onValueReceived.listen((value) {
      final resp = _decodeRacpResponse(value);
      onRacpResponse(resp);
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Step 3: Write Report All Stored Records (0x01 0x01)
    await racp.write([0x01, 0x01], withoutResponse: false);
  }

  // ── RACP response decoder ────────────────────────────────────────────────
  static String _decodeRacpResponse(List<int> data) {
    if (data.length < 4) return 'Invalid response';
    const responses = {
      1: 'Success - all records sent',
      2: 'Op Code not supported',
      3: 'Invalid Operator',
      4: 'Operator not supported',
      5: 'Invalid Operand',
      6: 'No records found',
      7: 'Abort unsuccessful',
      8: 'Procedure not completed',
      9: 'Operand not supported',
    };
    return responses[data[3]] ?? 'Unknown code ${data[3]}';
  }
}