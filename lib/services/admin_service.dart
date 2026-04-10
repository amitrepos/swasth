import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import '../config/app_config.dart';
import 'api_client.dart';

const _kTimeout = Duration(seconds: 20);

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
  /// Throws an [Exception] with a sentinel English message that callers
  /// are expected to replace with a localized string at the screen layer.
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
  }) async {
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
    try {
      final response = await ApiClient.httpClient
          .post(
            Uri.parse('$_baseUrl/users'),
            headers: ApiClient.headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception(ApiClient.errorDetail(response, 'Failed to create user'));
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection. Please try again.');
    } on FormatException {
      throw Exception('Server returned invalid data. Please try again later.');
    }
  }
}
