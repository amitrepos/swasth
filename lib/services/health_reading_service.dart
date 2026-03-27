import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_client.dart';

class HealthReading {
  final int id;
  final int userId;
  final String readingType; // 'glucose' or 'blood_pressure'
  
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
  
  // Common fields
  final double valueNumeric;
  final String unitDisplay;
  final String? statusFlag;
  final String? notes;
  final DateTime readingTimestamp;
  final DateTime createdAt;

  HealthReading({
    required this.id,
    required this.userId,
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
      userId: json['user_id'],
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
      'value_numeric': valueNumeric,
      'unit_display': unitDisplay,
      'status_flag': statusFlag,
      'notes': notes,
      'reading_timestamp': readingTimestamp.toIso8601String(),
    };
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
        userId: 0, // Will be set by backend
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
        userId: 0,
        readingType: 'blood_pressure',
        systolic: reading.systolic,
        diastolic: reading.diastolic,
        meanArterialPressure: reading.meanArterialPressure,
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

class HealthReadingService {
  static String baseUrl = '${AppConfig.serverHost}/api'; // Use /api prefix for health endpoints

  /// Save a new health reading
  Future<HealthReading> saveReading(HealthReading reading, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/readings'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(reading.toJson()),
      );
      if (response.statusCode == 201) return HealthReading.fromJson(jsonDecode(response.body));
      throw Exception(ApiClient.errorDetail(response, 'Failed to save reading'));
    } catch (e) {
      throw Exception('Failed to save reading: $e');
    }
  }

  /// Get user's readings with optional filtering
  Future<List<HealthReading>> getReadings({
    required String token,
    String? readingType,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      String url = '$baseUrl/readings?limit=$limit&offset=$offset';
      if (readingType != null) url += '&reading_type=$readingType';

      final response = await http.get(
        Uri.parse(url),
        headers: ApiClient.headers(token: token),
      );
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List).map((j) => HealthReading.fromJson(j)).toList();
      }
      throw Exception(ApiClient.errorDetail(response, 'Failed to get readings'));
    } catch (e) {
      throw Exception('Failed to get readings: $e');
    }
  }

  /// Get a specific reading by ID
  Future<HealthReading> getReading(int readingId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/readings/$readingId'),
        headers: ApiClient.headers(token: token),
      );
      if (response.statusCode == 200) return HealthReading.fromJson(jsonDecode(response.body));
      throw Exception(ApiClient.errorDetail(response, 'Reading not found'));
    } catch (e) {
      throw Exception('Failed to get reading: $e');
    }
  }

  /// Delete a reading
  Future<void> deleteReading(int readingId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/readings/$readingId'),
        headers: ApiClient.headers(token: token),
      );
      if (response.statusCode != 200) {
        throw Exception(ApiClient.errorDetail(response, 'Failed to delete reading'));
      }
    } catch (e) {
      throw Exception('Failed to delete reading: $e');
    }
  }

  /// Get summary statistics
  Future<Map<String, dynamic>> getSummary(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/readings/stats/summary'),
        headers: ApiClient.headers(token: token),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(ApiClient.errorDetail(response, 'Failed to get summary'));
    } catch (e) {
      throw Exception('Failed to get summary: $e');
    }
  }
}
