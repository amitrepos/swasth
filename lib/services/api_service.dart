import 'dart:convert';
import '../config/app_config.dart';
import 'api_client.dart';

const _kTimeout = Duration(seconds: 20);

class ApiService {
  static String baseUrl = AppConfig.apiBaseUrl;

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await ApiClient.httpClient
          .post(
            Uri.parse('$baseUrl/register'),
            headers: ApiClient.headers(),
            body: jsonEncode(userData),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 201) return jsonDecode(response.body);
      throw Exception(ApiClient.errorDetail(response, 'Registration failed'));
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiClient.httpClient
          .post(
            Uri.parse('$baseUrl/login'),
            headers: ApiClient.headers(),
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(ApiClient.errorDetail(response, 'Login failed'));
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    try {
      final response = await ApiClient.httpClient
          .get(
            Uri.parse('$baseUrl/me'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(
        ApiClient.errorDetail(response, 'Failed to get user data'),
      );
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      final response = await ApiClient.httpClient
          .post(
            Uri.parse('$baseUrl/forgot-password'),
            headers: ApiClient.headers(),
            body: jsonEncode({'email': email}),
          )
          .timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(ApiClient.errorDetail(response, 'Failed to send OTP'));
      }
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  Future<void> verifyOTP(String email, String otp) async {
    try {
      final response = await ApiClient.httpClient
          .post(
            Uri.parse('$baseUrl/verify-otp'),
            headers: ApiClient.headers(),
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(ApiClient.errorDetail(response, 'Invalid OTP'));
      }
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  Future<void> resetPassword(
    String email,
    String otp,
    String newPassword,
    String confirmPassword,
  ) async {
    try {
      final response = await ApiClient.httpClient
          .post(
            Uri.parse('$baseUrl/reset-password'),
            headers: ApiClient.headers(),
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'new_password': newPassword,
              'confirm_password': confirmPassword,
            }),
          )
          .timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          ApiClient.errorDetail(response, 'Failed to reset password'),
        );
      }
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  Future<void> sendEmailVerification(String token) async {
    try {
      final response = await ApiClient.httpClient
          .post(
            Uri.parse('$baseUrl/send-email-verification'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          ApiClient.errorDetail(response, 'Failed to send verification email'),
        );
      }
    } catch (e) {
      throw Exception('Failed to send verification email: $e');
    }
  }

  Future<void> verifyEmailOTP(String token, String otp) async {
    try {
      final response = await ApiClient.httpClient
          .post(
            Uri.parse('$baseUrl/verify-email'),
            headers: ApiClient.headers(token: token),
            body: jsonEncode({'otp': otp}),
          )
          .timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          ApiClient.errorDetail(response, 'Email verification failed'),
        );
      }
    } catch (e) {
      throw Exception('Failed to verify email: $e');
    }
  }

  Future<bool> getEmailVerificationStatus(String token) async {
    try {
      final response = await ApiClient.httpClient
          .get(
            Uri.parse('$baseUrl/email-verification-status'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['email_verified'] == true;
      }
      throw Exception(
        ApiClient.errorDetail(response, 'Failed to get verification status'),
      );
    } catch (e) {
      throw Exception('Failed to get email verification status: $e');
    }
  }

  Future<void> deleteAccount(String token) async {
    try {
      final response = await ApiClient.httpClient
          .delete(
            Uri.parse('$baseUrl/account'),
            headers: ApiClient.headers(token: token),
          )
          .timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(
          ApiClient.errorDetail(response, 'Failed to delete account'),
        );
      }
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> profileData,
  ) async {
    try {
      final response = await ApiClient.httpClient
          .put(
            Uri.parse('$baseUrl/profile'),
            headers: ApiClient.headers(token: token),
            body: jsonEncode(profileData),
          )
          .timeout(_kTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(
        ApiClient.errorDetail(response, 'Failed to update profile'),
      );
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}
