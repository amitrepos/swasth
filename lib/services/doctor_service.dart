import 'dart:convert';

import '../config/app_config.dart';
import 'api_client.dart';

/// API service for doctor portal endpoints (/api/doctor/*).
/// All methods throw [ApiException] subclasses on failure — never raw
/// [Exception]. Screens hand them to [ErrorMapper] for localization.
class DoctorService {
  static String get _baseUrl => '${AppConfig.serverHost}/api/doctor';

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$_baseUrl/register'),
        headers: ApiClient.headers(),
        body: jsonEncode(data),
      ),
      successCodes: const [201],
    );
  }

  Future<Map<String, dynamic>> getMyProfile(String token) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/me'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  /// Phase 4: pending patient link requests awaiting doctor review + attestation.
  Future<List<Map<String, dynamic>>> getPendingRequests(String token) async {
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/patients/pending'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Doctor accepts a pending link with an NMC attestation.
  /// [examinedOn] must be within the last 6 months per NMC Follow-up Consult rules.
  Future<Map<String, dynamic>> acceptPatientLink(
    String token,
    int profileId, {
    required DateTime examinedOn,
    required String condition,
  }) {
    final isoDate =
        '${examinedOn.year.toString().padLeft(4, '0')}-${examinedOn.month.toString().padLeft(2, '0')}-${examinedOn.day.toString().padLeft(2, '0')}';
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$_baseUrl/patients/$profileId/accept'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({
          'examined_on': isoDate,
          'examined_for_condition': condition,
        }),
      ),
      successCodes: const [200],
    );
  }

  Future<void> declinePatientLink(
    String token,
    int profileId, {
    String? reason,
  }) async {
    await ApiClient.send(
      () => ApiClient.httpClient.post(
        Uri.parse('$_baseUrl/patients/$profileId/decline'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        }),
      ),
      successCodes: const [200],
    );
  }

  Future<List<dynamic>> getTriageBoard(String token) {
    return ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/patients'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  Future<List<dynamic>> getPatientReadings(
    String token,
    int profileId, {
    int days = 30,
  }) {
    return ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/patients/$profileId/readings?days=$days'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  Future<Map<String, dynamic>> getPatientProfile(String token, int profileId) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/patients/$profileId/profile'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  Future<Map<String, dynamic>> getPatientSummary(String token, int profileId) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/patients/$profileId/summary'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  Future<Map<String, dynamic>> addNote(
    String token,
    int profileId,
    String noteText, {
    int? readingId,
  }) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$_baseUrl/patients/$profileId/notes'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({
          'note_text': noteText,
          if (readingId != null) 'reading_id': readingId,
        }),
      ),
      successCodes: const [201],
    );
  }

  Future<List<dynamic>> getNotes(String token, int profileId) {
    return ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/patients/$profileId/notes'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  Future<Map<String, dynamic>> lookupDoctor(String token, String doctorCode) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/lookup/$doctorCode'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  Future<Map<String, dynamic>> linkDoctor(
    String token,
    int profileId,
    String doctorCode,
    String consentType,
  ) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$_baseUrl/link/$profileId'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({
          'doctor_code': doctorCode,
          'consent_type': consentType,
        }),
      ),
      successCodes: const [201],
    );
  }

  /// Full directory of verified doctors on Swasth.
  Future<List<Map<String, dynamic>>> getDirectory(String token) async {
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/directory'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Deduped verified doctors linked to any profile the user owns.
  Future<List<Map<String, dynamic>>> getKnownDoctors(String token) async {
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/known-doctors'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<List<dynamic>> getLinkedDoctors(String token, int profileId) {
    return ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/link/$profileId'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  /// Patient revokes a doctor's access — DPDPA § 13 right-to-erasure path.
  Future<void> revokeDoctorLink(
    String token,
    int profileId,
    String doctorCode,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/link/$profileId',
    ).replace(queryParameters: {'doctor_code': doctorCode});
    await ApiClient.send(
      () => ApiClient.httpClient.delete(
        uri,
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [200, 204],
    );
  }
}
