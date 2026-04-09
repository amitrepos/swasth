import 'dart:convert';
import '../config/app_config.dart';
import 'api_client.dart';

const _kTimeout = Duration(seconds: 20);

/// API service for doctor portal endpoints (/api/doctor/*).
class DoctorService {
  static String get _baseUrl => '${AppConfig.serverHost}/api/doctor';

  /// Register a new doctor account.
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await ApiClient.httpClient
        .post(
          Uri.parse('$_baseUrl/register'),
          headers: ApiClient.headers(),
          body: jsonEncode(data),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception(
      ApiClient.errorDetail(response, 'Doctor registration failed'),
    );
  }

  /// Get current doctor's profile.
  Future<Map<String, dynamic>> getMyProfile(String token) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/me'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to get doctor profile'),
    );
  }

  /// Get triage board — all linked patients sorted by criticality.
  Future<List<dynamic>> getTriageBoard(String token) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/patients'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body) as List;
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to get triage board'),
    );
  }

  /// Get patient readings (doctor view).
  Future<List<dynamic>> getPatientReadings(
    String token,
    int profileId, {
    int days = 30,
  }) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/patients/$profileId/readings?days=$days'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body) as List;
    throw Exception(ApiClient.errorDetail(response, 'Failed to get readings'));
  }

  /// Get patient profile info (doctor view).
  Future<Map<String, dynamic>> getPatientProfile(
    String token,
    int profileId,
  ) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/patients/$profileId/profile'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to get patient profile'),
    );
  }

  /// Get 7-day summary for a patient.
  Future<Map<String, dynamic>> getPatientSummary(
    String token,
    int profileId,
  ) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/patients/$profileId/summary'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to get patient summary'),
    );
  }

  /// Add a clinical note on a patient.
  Future<Map<String, dynamic>> addNote(
    String token,
    int profileId,
    String noteText, {
    int? readingId,
  }) async {
    final body = <String, dynamic>{
      'note_text': noteText,
      if (readingId != null) 'reading_id': readingId,
    };
    final response = await ApiClient.httpClient
        .post(
          Uri.parse('$_baseUrl/patients/$profileId/notes'),
          headers: ApiClient.headers(token: token),
          body: jsonEncode(body),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception(ApiClient.errorDetail(response, 'Failed to add note'));
  }

  /// List doctor's notes on a patient.
  Future<List<dynamic>> getNotes(String token, int profileId) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/patients/$profileId/notes'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body) as List;
    throw Exception(ApiClient.errorDetail(response, 'Failed to get notes'));
  }

  /// Look up a doctor by code (used by patient app).
  Future<Map<String, dynamic>> lookupDoctor(
    String token,
    String doctorCode,
  ) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/lookup/$doctorCode'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(ApiClient.errorDetail(response, 'Doctor not found'));
  }

  /// Patient links to a doctor via doctor code.
  Future<Map<String, dynamic>> linkDoctor(
    String token,
    int profileId,
    String doctorCode,
    String consentType,
  ) async {
    final response = await ApiClient.httpClient
        .post(
          Uri.parse('$_baseUrl/link/$profileId'),
          headers: ApiClient.headers(token: token),
          body: jsonEncode({
            'doctor_code': doctorCode,
            'consent_type': consentType,
          }),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception(ApiClient.errorDetail(response, 'Failed to link doctor'));
  }

  /// List doctors linked to a profile.
  Future<List<dynamic>> getLinkedDoctors(String token, int profileId) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/link/$profileId'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return jsonDecode(response.body) as List;
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to get linked doctors'),
    );
  }
}
