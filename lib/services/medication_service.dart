// HTTP service for medication intake endpoints (NUO-127).
// Related: backend/routes_medications.py, lib/models/medication_model.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/medication_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

class MedicationService {
  static String get _baseUrl => '${AppConfig.serverHost}/api/medications';

  /// POST /api/medications — log a taken medicine.
  Future<Medication> saveMedication(MedicationCreate data, String token) async {
    return saveMedicationWithPhoto(data, token);
  }

  /// POST /api/medications (multipart) — optionally attach package photo.
  Future<Medication> saveMedicationWithPhoto(
    MedicationCreate data,
    String token, {
    PlatformFile? photo,
  }) async {
    if (photo == null) {
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

    final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
    final headers = ApiClient.headers(token: token);
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    request.fields['profile_id'] = data.profileId.toString();
    request.fields['name'] = data.name;
    if (data.dose != null && data.dose!.isNotEmpty)
      request.fields['dose'] = data.dose!;
    if (data.frequency != null && data.frequency!.isNotEmpty) {
      request.fields['frequency'] = data.frequency!;
    }
    request.fields['intake_period'] = data.intakePeriod;
    request.fields['taken_at'] = data.takenAt.toUtc().toIso8601String();
    if (data.notes != null && data.notes!.isNotEmpty)
      request.fields['notes'] = data.notes!;

    final bytes = await _platformFileBytes(photo);
    request.files.add(
      http.MultipartFile.fromBytes('photo', bytes, filename: photo.name),
    );

    final response = await ApiClient.send(() async {
      final streamed = await ApiClient.httpClient.send(request);
      return http.Response.fromStream(streamed);
    }, successCodes: const [201]);
    return Medication.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// PATCH /api/medications/{id} — edit an existing log.
  Future<Medication> updateMedication(
    int medId,
    MedicationUpdate data,
    String token,
  ) async {
    final body = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.patch(
        Uri.parse('$_baseUrl/$medId'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(data.toJson()),
      ),
      successCodes: const [200],
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
    return list
        .map((j) => Medication.fromJson(j as Map<String, dynamic>))
        .toList();
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

  Future<Uint8List> fetchMedicationPhoto(int medId, String token) async {
    final response = await ApiClient.send(
      () => ApiClient.httpClient.get(
        Uri.parse('$_baseUrl/$medId/photo'),
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [200],
    );
    return response.bodyBytes;
  }

  Future<Uint8List> _platformFileBytes(PlatformFile file) => file.bytes != null
      ? Future.value(file.bytes!)
      : Future.error(
          const ValidationException('Selected image is unreadable.'),
        );
}
