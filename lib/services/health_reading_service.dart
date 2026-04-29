import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/ocr_service.dart';
import '../utils/datetime_utils.dart';
import 'api_client.dart';
import 'api_exception.dart';

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

  // Weight fields
  final double? weightValue;
  final String? weightUnit;

  // Common fields
  final double valueNumeric;
  final String unitDisplay;
  final String? statusFlag;
  final String? notes;
  final DateTime readingTimestamp;
  final int? seq; // Device sequence number for BLE deduplication
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
    this.weightValue,
    this.weightUnit,
    required this.valueNumeric,
    required this.unitDisplay,
    this.statusFlag,
    this.notes,
    required this.readingTimestamp,
    this.seq,
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
      weightValue: json['weight_value']?.toDouble(),
      weightUnit: json['weight_unit'],
      // value_numeric can be null for reading types that don't produce a
      // single scalar (e.g. blood_pressure returns systolic/diastolic).
      // Previously this crashed fromJson and propagated as "error loading
      // history" even when the underlying list was perfectly valid.
      valueNumeric: (json['value_numeric'] as num?)?.toDouble() ?? 0,
      unitDisplay: json['unit_display'] ?? '',
      statusFlag: json['status_flag'],
      notes: json['notes'],
      readingTimestamp: DateTimeUtils.parseUtc(json['reading_timestamp']),
      seq: json['seq'],
      createdAt: json['created_at'] != null
          ? DateTimeUtils.parseUtc(json['created_at'])
          : DateTimeUtils.parseUtc(json['reading_timestamp']),
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
      'weight_value': weightValue,
      'weight_unit': weightUnit,
      'value_numeric': valueNumeric,
      'unit_display': unitDisplay,
      'status_flag': statusFlag,
      'notes': notes,
      'reading_timestamp': readingTimestamp.toUtc().toIso8601String(),
      'seq': seq,
    };
  }

  /// Full JSON including server-assigned fields — used for local caching.
  Map<String, dynamic> toCacheJson() {
    return {'id': id, ...toJson(), 'created_at': createdAt.toIso8601String()};
  }

  String get displayValue {
    if (readingType == 'glucose') {
      return '${glucoseValue?.toStringAsFixed(1) ?? '-'} $unitDisplay';
    } else if (readingType == 'weight') {
      return '${weightValue?.toStringAsFixed(1) ?? '-'} $unitDisplay';
    } else if (readingType == 'steps') {
      return '${stepsCount?.toString() ?? '-'} $unitDisplay';
    } else if (readingType == 'spo2') {
      return '${spo2Value?.toStringAsFixed(0) ?? '-'} $unitDisplay';
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
        seq: reading.sequenceNumber, // Pass BLE sequence number
        createdAt: now,
      );
    } else if (deviceType.toLowerCase().contains('blood')) {
      // It's a BPReading
      // Parse timestamp string to DateTime
      DateTime bpTimestamp;
      try {
        bpTimestamp = DateTime.parse(reading.timestamp);
      } catch (e) {
        bpTimestamp = now; // Fallback to current time if parsing fails
      }

      return HealthReading(
        id: 0,
        profileId: 0,
        readingType: 'blood_pressure',
        systolic: reading.systolicMmhg.toDouble(),
        diastolic: reading.diastolicMmhg.toDouble(),
        meanArterialPressure: reading.mapMmhg,
        pulseRate: reading.pulseBpm.toDouble(),
        bpUnit: 'mmHg',
        bpStatus: reading.bpCategory,
        valueNumeric: reading.systolicMmhg.toDouble(),
        unitDisplay: 'mmHg',
        statusFlag: reading.bpCategory,
        notes: null,
        readingTimestamp: bpTimestamp,
        seq: reading.seq, // Pass BLE sequence number
        createdAt: now,
      );
    }

    throw Exception('Unknown device type: $deviceType');
  }
}

class HealthReadingService {
  // Use /api prefix for health endpoints.
  static String baseUrl = '${AppConfig.serverHost}/api';

  /// Save a new health reading. Returns {reading, alert?, skipped?} map.
  Future<Map<String, dynamic>> saveReading(
    HealthReading reading,
    String token,
  ) async {
    final body = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/readings'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(reading.toJson()),
      ),
      successCodes: const [201],
    );
    if (body['skipped'] == true) {
      return {
        'skipped': true,
        'reason': body['reason'],
        'seq': body['seq'],
        'existing_id': body['existing_id'],
      };
    }
    return {'reading': HealthReading.fromJson(body), 'alert': body['alert']};
  }

  /// Save steps reading to backend.
  Future<void> saveStepsReading({
    required String token,
    required int profileId,
    required int stepsCount,
    required int stepsGoal,
  }) async {
    final reading = HealthReading(
      id: 0,
      profileId: profileId,
      readingType: 'steps',
      stepsCount: stepsCount,
      stepsGoal: stepsGoal,
      valueNumeric: stepsCount.toDouble(),
      unitDisplay: 'steps',
      readingTimestamp: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
    );
    await ApiClient.send(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/readings'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(reading.toJson()),
      ),
      successCodes: const [201],
    );
  }

  /// Get user's readings with optional filtering.
  Future<List<HealthReading>> getReadings({
    required String token,
    required int profileId,
    String? readingType,
    int limit = 100,
    int offset = 0,
  }) async {
    var url =
        '$baseUrl/readings?profile_id=$profileId&limit=$limit&offset=$offset';
    if (readingType != null) url += '&reading_type=$readingType';
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse(url),
        headers: ApiClient.headers(token: token),
      ),
    );
    return list.map((j) => HealthReading.fromJson(j)).toList();
  }

  /// Get a specific reading by ID.
  Future<HealthReading> getReading(int readingId, String token) async {
    final body = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$baseUrl/readings/$readingId'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return HealthReading.fromJson(body);
  }

  /// Delete a reading.
  Future<void> deleteReading(int readingId, String token) async {
    await ApiClient.send(
      () => ApiClient.httpClient.delete(
        Uri.parse('$baseUrl/readings/$readingId'),
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [200, 204],
    );
  }

  /// Get AI Doctor recommendation from Gemini via backend.
  ///
  /// Non-critical enrichment: returns empty string on [NetworkException] or
  /// [ServerException] (home screen degrades gracefully). [UnauthorizedException]
  /// still propagates so the app-wide 401 handler fires.
  Future<String> getAiInsight(String token, int profileId) async {
    try {
      final data = await ApiClient.sendJsonObject(
        () => ApiClient.httpClient.get(
          Uri.parse('$baseUrl/readings/ai-insight?profile_id=$profileId'),
          headers: ApiClient.headers(token: token),
        ),
      );
      final insight = (data['insight'] as String?) ?? '';
      
      // DEBUG: Log AI insight received (only in debug mode)
      debugPrint('\n${'='*80}\n🟡 FRONTEND AI INSIGHT RECEIVED:\n${'='*80}\n$insight\n${'='*80}\n');
      
      return insight;
    } on UnauthorizedException {
      rethrow;
    } on ApiException {
      return '';
    }
  }

  /// Get AI trend summary for a period (7, 30, or 90 days).
  /// Non-critical enrichment — returns empty on non-auth failure.
  Future<String> getTrendSummary(
    String token,
    int profileId,
    int period,
  ) async {
    try {
      final data = await ApiClient.sendJsonObject(
        () => ApiClient.httpClient.get(
          Uri.parse(
            '$baseUrl/readings/trend-summary?profile_id=$profileId&period=$period',
          ),
          headers: ApiClient.headers(token: token),
        ),
        timeout: const Duration(seconds: 45),
      );
      return (data['summary'] as String?) ?? '';
    } on UnauthorizedException {
      rethrow;
    } on ApiException {
      return '';
    }
  }

  /// Send a device photo to the backend and use Gemini Vision to extract
  /// the reading values. Returns an OcrResult on success, null on failure.
  /// Caller falls back to local OCR when null is returned.
  Future<OcrResult?> parseImageWithGemini(
    Uint8List imageBytes,
    String fileName,
    String deviceType,
    String token,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/readings/parse-image?device_type=$deviceType',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(ApiClient.headers(token: token))
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));

    http.Response response;
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      // Transport failure during multipart — let caller fall back to local OCR.
      return null;
    }

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode != 200) return null;

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
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
    } else if (deviceType == 'weight') {
      final weight = (data['weight'] as num?)?.toDouble();
      if (weight == null) return null;
      return OcrResult(
        readingType: 'weight',
        weightValue: weight,
        rawText: 'Gemini: $weight kg',
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
  }

  /// Get computed health score, streak, and AI insight for the home screen.
  Future<Map<String, dynamic>> getHealthScore(String token, int profileId) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$baseUrl/readings/health-score?profile_id=$profileId'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  /// Get streaks and points for all accessible profiles (family leaderboard).
  /// Non-critical enrichment — returns empty on non-auth failure.
  Future<List<Map<String, dynamic>>> getFamilyStreaks(String token) async {
    try {
      final data = await ApiClient.sendJsonObject(
        () => ApiClient.httpClient.get(
          Uri.parse('$baseUrl/readings/family-streaks'),
          headers: ApiClient.headers(token: token),
        ),
      );
      return List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
    } on UnauthorizedException {
      rethrow;
    } on ApiException {
      return [];
    }
  }

  /// Get shareable weekly summary text for a profile.
  /// Non-critical enrichment — returns empty on non-auth failure.
  Future<Map<String, dynamic>> getWeeklySummary(
    String token,
    int profileId,
  ) async {
    try {
      return await ApiClient.sendJsonObject(
        () => ApiClient.httpClient.get(
          Uri.parse(
            '$baseUrl/readings/trend-summary?profile_id=$profileId&period=7&format=text',
          ),
          headers: ApiClient.headers(token: token),
        ),
      );
    } on UnauthorizedException {
      rethrow;
    } on ApiException {
      return {};
    }
  }
}
