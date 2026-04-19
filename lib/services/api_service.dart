import 'dart:convert';

import '../config/app_config.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Authentication + profile API. Every method returns on success or throws
/// a typed [ApiException] via [ApiClient.send] — never a raw Dart
/// exception. Consumers (screens) catch [Object] and hand to [ErrorMapper]
/// for localization + 401 auto-logout.
class ApiService {
  static String baseUrl = AppConfig.apiBaseUrl;

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/register'),
        headers: ApiClient.headers(),
        body: jsonEncode(userData),
      ),
      successCodes: const [201],
    );
  }

  /// Login is a special case: the backend returns 401 to mean "wrong
  /// credentials", not "session expired". We catch that here and rethrow
  /// as [ValidationException] so the login screen shows the detail
  /// ("Incorrect email or password") instead of triggering the global
  /// 401 auto-logout flow in [ErrorMapper].
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await ApiClient.send(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/login'),
        headers: ApiClient.headers(),
        body: jsonEncode({'email': email, 'password': password}),
      ),
      successCodes: const [200, 401],
    );
    if (response.statusCode == 401) {
      throw ValidationException(
        ApiClient.errorDetail(response, 'Incorrect email or password.'),
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const ServerException();
    }
  }

  Future<Map<String, dynamic>> getCurrentUser(String token) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$baseUrl/me'),
        headers: ApiClient.headers(token: token),
      ),
    );
  }

  Future<void> requestPasswordReset(String email) async {
    await ApiClient.send(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: ApiClient.headers(),
        body: jsonEncode({'email': email}),
      ),
      successCodes: const [200],
    );
  }

  Future<void> verifyOTP(String email, String otp) async {
    await ApiClient.send(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: ApiClient.headers(),
        body: jsonEncode({'email': email, 'otp': otp}),
      ),
      successCodes: const [200],
    );
  }

  Future<void> resetPassword(
    String email,
    String otp,
    String newPassword,
    String confirmPassword,
  ) async {
    await ApiClient.send(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: ApiClient.headers(),
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      ),
      successCodes: const [200],
    );
  }

  Future<void> sendEmailVerification(String token) async {
    await ApiClient.send(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/send-email-verification'),
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [200],
    );
  }

  Future<void> verifyEmailOTP(String token, String otp) async {
    await ApiClient.send(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/verify-email'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({'otp': otp}),
      ),
      successCodes: const [200],
    );
  }

  Future<bool> getEmailVerificationStatus(String token) async {
    final data = await ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$baseUrl/email-verification-status'),
        headers: ApiClient.headers(token: token),
      ),
    );
    return data['email_verified'] == true;
  }

  Future<void> deleteAccount(String token) async {
    await ApiClient.send(
      () => ApiClient.httpClient.delete(
        Uri.parse('$baseUrl/account'),
        headers: ApiClient.headers(token: token),
      ),
      successCodes: const [200, 204],
    );
  }

  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> profileData,
  ) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.put(
        Uri.parse('$baseUrl/profile'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(profileData),
      ),
    );
  }
}
