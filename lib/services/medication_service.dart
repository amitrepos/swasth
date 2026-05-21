// HTTP service for medication intake endpoints (NUO-127).
// Related: backend/routes_medications.py, lib/models/medication_model.dart
import 'dart:convert';

import '../config/app_config.dart';
import '../models/medication_model.dart';
import 'api_client.dart';

class MedicationService {
  static String get _baseUrl => '${AppConfig.serverHost}/api/medications';

  /// POST /api/medications — log a taken medicine.
  Future<Medication> saveMedication(MedicationCreate data, String token) async {
    final body = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse(_baseUrl),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(data.toJson()),
      ),
      successCodes: const [201],
    );
    return Medication.fromJson(body);
  }

  /// GET /api/medications?profile_id=X&days=Y — recent log.
  Future<List<Medication>> getMedications(
    int profileId,
    String token, {
    int days = 30,
  }) async {
    final list = await ApiClient.sendJsonList(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl?profile_id=$profileId&days=$days'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return list.map((j) => Medication.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// DELETE /api/medications/{id}.
  Future<void> deleteMedication(int medId, String token) async {
    await ApiClient.send(
      () => ApiClient.httpClient.delete(
        Uri.parse('$_baseUrl/$medId'),
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [200, 204],
    );
  }
}
