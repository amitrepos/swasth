import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/ocr_service.dart';
import 'api_client.dart';

class HealthReading {
  final int id;
  int profileId;
  final String readingType; // 'glucose', 'blood_pressure', 'spo2', or 'steps'

  // Glucose fields
  final double? glucoseValue;
  final String? glucoseUnit;
  final String? sampleType;

  // BP fields
  final double? systolic;
  final double? diastolic;
  final double? meanArterialPressure;
  final double? pulseRate;
  final String? bpUnit;
  final String? bpStatus;

  // SpO2 fields
  final double? spo2Value;
  final String? spo2Unit;

  // Steps fields
  final int? stepsCount;
  final int? stepsGoal;

  // Common fields
  final double valueNumeric;
  final String unitDisplay;
  final String? statusFlag;
  final String? notes;
  final DateTime readingTimestamp;
  final DateTime createdAt;

  HealthReading({
    required this.id,
    required this.profileId,
    required this.readingType,
    this.glucoseValue,
    this.glucoseUnit,
    this.sampleType,
    this.systolic,
    this.diastolic,
    this.meanArterialPressure,
    this.pulseRate,
    this.bpUnit,
    this.bpStatus,
    this.spo2Value,
    this.spo2Unit,
    this.stepsCount,
    this.stepsGoal,
    required this.valueNumeric,
    required this.unitDisplay,
    this.statusFlag,
    this.notes,
    required this.readingTimestamp,
    required this.createdAt,
  });

  factory HealthReading.fromJson(Map<String, dynamic> json) {
    return HealthReading(
      id: json['id'],
      profileId: json['profile_id'],
      readingType: json['reading_type'],
      glucoseValue: json['glucose_value']?.toDouble(),
      glucoseUnit: json['glucose_unit'],
      sampleType: json['sample_type'],
      systolic: json['systolic']?.toDouble(),
      diastolic: json['diastolic']?.toDouble(),
      meanArterialPressure: json['mean_arterial_pressure']?.toDouble(),
      pulseRate: json['pulse_rate']?.toDouble(),
      bpUnit: json['bp_unit'],
      bpStatus: json['bp_status'],
      spo2Value: json['spo2_value']?.toDouble(),
      spo2Unit: json['spo2_unit'],
      stepsCount: json['steps_count']?.toInt(),
      stepsGoal: json['steps_goal']?.toInt(),
      valueNumeric: json['value_numeric'].toDouble(),
      unitDisplay: json['unit_display'],
      statusFlag: json['status_flag'],
      notes: json['notes'],
      readingTimestamp: DateTime.parse(json['reading_timestamp']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'reading_type': readingType,
      'glucose_value': glucoseValue,
      'glucose_unit': glucoseUnit,
      'sample_type': sampleType,
      'systolic': systolic,
      'diastolic': diastolic,
      'mean_arterial_pressure': meanArterialPressure,
      'pulse_rate': pulseRate,
      'bp_unit': bpUnit,
      'bp_status': bpStatus,
      'spo2_value': spo2Value,
      'spo2_unit': spo2Unit,
      'steps_count': stepsCount,
      'steps_goal': stepsGoal,
      'value_numeric': valueNumeric,
      'unit_display': unitDisplay,
      'status_flag': statusFlag,
      'notes': notes,
      'reading_timestamp': readingTimestamp.toIso8601String(),
    };
  }

  /// Full JSON including server-assigned fields — used for local caching.
  Map<String, dynamic> toCacheJson() {
    return {'id': id, ...toJson(), 'created_at': createdAt.toIso8601String()};
  }

  String get displayValue {
    if (readingType == 'glucose') {
      return '${glucoseValue?.toStringAsFixed(1) ?? '-'} $unitDisplay';
    } else {
      return '${systolic?.toStringAsFixed(0) ?? '-'}/${diastolic?.toStringAsFixed(0) ?? '-'} $unitDisplay';
    }
  }

  String get statusDescription {
    switch (statusFlag) {
      case 'NORMAL':
        return 'Normal';
      case 'ELEVATED':
        return 'Elevated';
      case 'HIGH - STAGE 1':
        return 'High - Stage 1';
      case 'HIGH - STAGE 2':
        return 'High - Stage 2';
      default:
        return statusFlag ?? '';
    }
  }

  // Factory method to create from GlucoseReading or BPReading
  factory HealthReading.fromGlucoseOrBP(dynamic reading, String deviceType) {
    final now = DateTime.now();

    if (deviceType.toLowerCase().contains('glucose')) {
      // It's a GlucoseReading
      return HealthReading(
        id: 0, // Will be assigned by database
        profileId: 0, // Will be set by caller
        readingType: 'glucose',
        glucoseValue: reading.mgdl,
        glucoseUnit: 'mg/dL', // GlucoseReading uses mg/dL by default
        sampleType: reading.sampleType,
        valueNumeric: reading.mgdl ?? 0,
        unitDisplay: 'mg/dL',
        statusFlag: reading.flag,
        notes: null,
        readingTimestamp: reading.timestamp ?? now,
        createdAt: now,
      );
    } else if (deviceType.toLowerCase().contains('blood')) {
      // It's a BPReading
      return HealthReading(
        id: 0,
        profileId: 0,
        readingType: 'blood_pressure',
        systolic: reading.systolic,
        diastolic: reading.diastolic,
        meanArterialPressure: reading.mean_arterial_pressure,
        pulseRate: reading.pulseRate,
        bpUnit: reading.unit ?? 'mmHg',
        bpStatus: reading.flag,
        valueNumeric: reading.systolic ?? 0,
        unitDisplay: reading.unit ?? 'mmHg',
        statusFlag: reading.flag,
        notes: null,
        readingTimestamp: reading.timestamp ?? now,
        createdAt: now,
      );
    }

    throw Exception('Unknown device type: $deviceType');
  }
}

const _kTimeout = Duration(seconds: 20);

class HealthReadingService {
  static String baseUrl =
      '${AppConfig.serverHost}/api'; // Use /api prefix for health endpoints

  /// Save a new health reading. Returns {reading, alert?} map.
  Future<Map<String, dynamic>> saveReading(
    HealthReading reading,
    String token,
  ) async {
    try {
      final response = await ApiClient.httpClient
          .post(
            Uri.parse('$baseUrl/readings'),
            headers: ApiClient.headers(token: token),
            body: jsonEncode(reading.toJson()),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return {
          'reading': HealthReading.fromJson(body),
          'alert': body['alert'],
        };
      }
      throw Exception(
        ApiClient.errorDetail(response, 'Failed to save reading'),
      );
    } catch (e) {
      throw Exception('Failed to save reading: $e');
    }
  }

  /// Get user's readings with optional filtering
  Future<List<HealthReading>> getReadings({
    required String token,
    required int profileId,
    String? readingType,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      String url =
          '$baseUrl/readings?profile_id=$profileId&limit=$limit&offset=$offset';
      if (readingType != null) url += '&reading_type=$readingType';

      final response = await ApiClient.httpClient
          .get(Uri.parse(url), headers: ApiClient.headers(token: token))
          .timeout(_kTimeout);
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List)
            .map((j) => HealthReading.fromJson(j))
            .toList();
      }
      throw Exception(
        ApiClient.errorDetail(response, 'Failed to get readings'),
      );
    } catch (e) {
      throw Exception('Failed to get readings: $e');
    }
  }

  /// Get a specific reading by ID
  Future<HealthReading> getReading(int readingId, String token) async {
    try {
      final response = await ApiClient.httpClient
          .get(
            Uri.parse('$baseUrl/readings/$readingId'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200)
        return HealthReading.fromJson(jsonDecode(response.body));
      throw Exception(ApiClient.errorDetail(response, 'Reading not found'));
    } catch (e) {
      throw Exception('Failed to get reading: $e');
    }
  }

  /// Delete a reading
  Future<void> deleteReading(int readingId, String token) async {
    try {
      final response = await ApiClient.httpClient
          .delete(
            Uri.parse('$baseUrl/readings/$readingId'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          ApiClient.errorDetail(response, 'Failed to delete reading'),
        );
      }
    } catch (e) {
      throw Exception('Failed to delete reading: $e');
    }
  }


  /// Get AI Doctor recommendation from Gemini via backend
  Future<String> getAiInsight(String token, int profileId) async {
    try {
      final response = await ApiClient.httpClient
          .get(
            Uri.parse('$baseUrl/readings/ai-insight?profile_id=$profileId'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['insight'] as String?) ?? '';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// Get AI trend summary for a period (7, 30, or 90 days).
  /// Combines health readings + chat memory + profile info for pattern analysis.
  Future<String> getTrendSummary(
    String token,
    int profileId,
    int period,
  ) async {
    try {
      final response = await ApiClient.httpClient
          .get(
            Uri.parse(
              '$baseUrl/readings/trend-summary?profile_id=$profileId&period=$period',
            ),
            headers: ApiClient.headers(token: token),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['summary'] as String?) ?? '';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// Send a device photo to the backend and use Gemini Vision to extract
  /// the reading values. Returns an OcrResult on success, null on failure.
  /// Caller should fall back to local OCR when null is returned.
  Future<OcrResult?> parseImageWithGemini(
    File imageFile,
    String deviceType,
    String token,
  ) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/readings/parse-image?device_type=$deviceType',
      );
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(ApiClient.headers(token: token))
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('error')) return null;

      if (deviceType == 'blood_pressure') {
        final sys = (data['systolic'] as num?)?.toDouble();
        final dia = (data['diastolic'] as num?)?.toDouble();
        final pulse = (data['pulse'] as num?)?.toDouble();
        if (sys == null || dia == null) return null;
        return OcrResult(
          readingType: 'blood_pressure',
          systolic: sys,
          diastolic: dia,
          pulse: pulse,
          rawText: 'Gemini: $sys/$dia mmHg${pulse != null ? ' ♥$pulse' : ''}',
        );
      } else {
        final glucose = (data['glucose'] as num?)?.toDouble();
        if (glucose == null) return null;
        return OcrResult(
          readingType: 'glucose',
          glucoseValue: glucose,
          rawText: 'Gemini: $glucose mg/dL',
        );
      }
    } catch (_) {
      return null;
    }
  }

  /// Get computed health score, streak, and AI insight for the home screen
  Future<Map<String, dynamic>> getHealthScore(
    String token,
    int profileId,
  ) async {
    try {
      final response = await ApiClient.httpClient
          .get(
            Uri.parse('$baseUrl/readings/health-score?profile_id=$profileId'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(
        ApiClient.errorDetail(response, 'Failed to get health score'),
      );
    } catch (e) {
      throw Exception('Failed to get health score: $e');
    }
  }

  /// Get streaks and points for all accessible profiles (family leaderboard).
  Future<List<Map<String, dynamic>>> getFamilyStreaks(String token) async {
    try {
      final response = await ApiClient.httpClient
          .get(
            Uri.parse('$baseUrl/readings/family-streaks'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get shareable weekly summary text for a profile.
  Future<Map<String, dynamic>> getWeeklySummary(
    String token,
    int profileId,
  ) async {
    try {
      final response = await ApiClient.httpClient
          .get(
            Uri.parse('$baseUrl/readings/trend-summary?profile_id=$profileId&period=7&format=text'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}
