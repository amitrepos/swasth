import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_client.dart';

const _kTimeout = Duration(seconds: 20);

class ApiService {
  static String baseUrl = AppConfig.apiBaseUrl;

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: ApiClient.headers(),
        body: jsonEncode(userData),
      ).timeout(_kTimeout);
      if (response.statusCode == 201) return jsonDecode(response.body);
      throw Exception(ApiClient.errorDetail(response, 'Registration failed'));
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: ApiClient.headers(),
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(_kTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(ApiClient.errorDetail(response, 'Login failed'));
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: ApiClient.headers(token: token),
      ).timeout(_kTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(ApiClient.errorDetail(response, 'Failed to get user data'));
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: ApiClient.headers(),
        body: jsonEncode({'email': email}),
      ).timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(ApiClient.errorDetail(response, 'Failed to send OTP'));
      }
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  Future<void> verifyOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: ApiClient.headers(),
        body: jsonEncode({'email': email, 'otp': otp}),
      ).timeout(_kTimeout);
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
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: ApiClient.headers(),
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      ).timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(ApiClient.errorDetail(response, 'Failed to reset password'));
      }
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  Future<void> deleteAccount(String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/account'),
        headers: ApiClient.headers(token: token),
      ).timeout(_kTimeout);
      if (response.statusCode != 200) {
        throw Exception(ApiClient.errorDetail(response, 'Failed to delete account'));
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
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode(profileData),
      ).timeout(_kTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(ApiClient.errorDetail(response, 'Failed to update profile'));
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
}
