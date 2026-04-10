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

  /// Phase 4: return pending patient link requests awaiting the
  /// current doctor's review + attestation.
  Future<List<Map<String, dynamic>>> getPendingRequests(String token) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/patients/pending'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to load pending requests'),
    );
  }

  /// Phase 4: doctor accepts a pending link with an NMC attestation.
  /// [examinedOn] must be within the last 6 months per NMC Follow-up
  /// Consult rules. [condition] is the clinical context the doctor
  /// examined the patient for (≥3 characters).
  Future<Map<String, dynamic>> acceptPatientLink(
    String token,
    int profileId, {
    required DateTime examinedOn,
    required String condition,
  }) async {
    final isoDate =
        '${examinedOn.year.toString().padLeft(4, '0')}-${examinedOn.month.toString().padLeft(2, '0')}-${examinedOn.day.toString().padLeft(2, '0')}';
    final response = await ApiClient.httpClient
        .post(
          Uri.parse('$_baseUrl/patients/$profileId/accept'),
          headers: ApiClient.headers(token: token),
          body: jsonEncode({
            'examined_on': isoDate,
            'examined_for_condition': condition,
          }),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to accept patient'),
    );
  }

  /// Phase 4: doctor declines a pending link with an optional reason.
  Future<void> declinePatientLink(
    String token,
    int profileId, {
    String? reason,
  }) async {
    final response = await ApiClient.httpClient
        .post(
          Uri.parse('$_baseUrl/patients/$profileId/decline'),
          headers: ApiClient.headers(token: token),
          body: jsonEncode({
            if (reason != null && reason.isNotEmpty) 'reason': reason,
          }),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) return;
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to decline patient'),
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

  /// Return deduped verified doctors linked to any profile the
  /// authenticated user owns — used to populate the Link Doctor picker
  /// so patients don't have to remember a code.
  ///
  /// Each entry is a map with `doctor_name`, `specialty`, `clinic_name`,
  /// `doctor_code`, `is_verified`, and `linked_profile_ids` (a list of int).
  Future<List<Map<String, dynamic>>> getKnownDoctors(String token) async {
    final response = await ApiClient.httpClient
        .get(
          Uri.parse('$_baseUrl/known-doctors'),
          headers: ApiClient.headers(token: token),
        )
        .timeout(_kTimeout);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to load known doctors'),
    );
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

  /// Patient revokes a doctor's access to their profile — DPDPA § 13
  /// right-to-erasure path. Sets [DoctorPatientLink.is_active] to false
  /// on the backend; the doctor immediately loses read access to the
  /// profile's readings and triage data.
  Future<void> revokeDoctorLink(
    String token,
    int profileId,
    String doctorCode,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/link/$profileId',
    ).replace(queryParameters: {'doctor_code': doctorCode});
    final response = await ApiClient.httpClient
        .delete(uri, headers: ApiClient.headers(token: token))
        .timeout(_kTimeout);
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw Exception(
      ApiClient.errorDetail(response, 'Failed to revoke doctor access'),
    );
  }
}
