import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_client.dart';

const _kTimeout = Duration(seconds: 30); // Chat may take longer than typical API calls

class ChatService {
  static String baseUrl = '${AppConfig.serverHost}/api';

  Future<Map<String, dynamic>> sendMessage(String token, int profileId, String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/send'),
      headers: ApiClient.headers(token: token),
      body: jsonEncode({'profile_id': profileId, 'message': message}),
    ).timeout(_kTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(ApiClient.errorDetail(response, 'Failed to send message'));
  }

  Future<Map<String, dynamic>> sendImageMessage(String token, int profileId, String message, String imageBase64) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/send'),
      headers: ApiClient.headers(token: token),
      body: jsonEncode({
        'profile_id': profileId,
        'message': message,
        'image_base64': imageBase64,
      }),
    ).timeout(const Duration(seconds: 60)); // Vision takes longer

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(ApiClient.errorDetail(response, 'Failed to analyze image'));
  }

  Future<Map<String, dynamic>> getMessages(String token, int profileId, {int limit = 50}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/messages?profile_id=$profileId&limit=$limit'),
      headers: ApiClient.headers(token: token),
    ).timeout(_kTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(ApiClient.errorDetail(response, 'Failed to load messages'));
  }

  Future<Map<String, dynamic>> getQuota(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/quota'),
      headers: ApiClient.headers(token: token),
    ).timeout(_kTimeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(ApiClient.errorDetail(response, 'Failed to load quota'));
  }
}
