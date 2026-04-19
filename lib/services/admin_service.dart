import 'dart:convert';

import '../config/app_config.dart';
import 'api_client.dart';

/// API service for admin-only endpoints (/api/admin/*).
///
/// ⚠️ All methods on this service require the caller to be authenticated
/// as a user with `is_admin=True`. Calls will return 403 otherwise.
/// Do NOT call from patient-facing screens.
class AdminService {
  static String get _baseUrl => '${AppConfig.serverHost}/api/admin';

  /// Admin creates a patient account (G6).
  ///
  /// [role] must be 'patient'; 'doctor' is currently rejected by the
  /// backend (501) until the first-login doctor-consent flow is built.
  /// Throws an [ApiException] subclass on failure — screens hand to
  /// [ErrorMapper] for localization.
  Future<Map<String, dynamic>> createUser(
    String token, {
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String role,
    String? nmcNumber,
    String? specialty,
    String? clinicName,
  }) {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'role': role,
      if (nmcNumber != null && nmcNumber.isNotEmpty) 'nmc_number': nmcNumber,
      if (specialty != null && specialty.isNotEmpty) 'specialty': specialty,
      if (clinicName != null && clinicName.isNotEmpty)
        'clinic_name': clinicName,
    };
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$_baseUrl/users'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(body),
      ),
      successCodes: const [201],
    );
  }
}
