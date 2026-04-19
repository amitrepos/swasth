import 'dart:convert';

import '../config/app_config.dart';
import 'api_client.dart';

/// Chat service uses a longer timeout than generic API calls because AI
/// responses (especially vision) can legitimately take tens of seconds.
const _kChatTimeout = Duration(seconds: 30);
const _kVisionTimeout = Duration(seconds: 60);

class ChatService {
  static String baseUrl = '${AppConfig.serverHost}/api';

  Future<Map<String, dynamic>> sendMessage(
    String token,
    int profileId,
    String message,
  ) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/chat/send'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({'profile_id': profileId, 'message': message}),
      ),
      timeout: _kChatTimeout,
    );
  }

  Future<Map<String, dynamic>> sendImageMessage(
    String token,
    int profileId,
    String message,
    String imageBase64,
  ) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.post(
        Uri.parse('$baseUrl/chat/send'),
        headers: ApiClient.headers(token: token),
        body: jsonEncode({
          'profile_id': profileId,
          'message': message,
          'image_base64': imageBase64,
        }),
      ),
      timeout: _kVisionTimeout,
    );
  }

  Future<Map<String, dynamic>> getMessages(
    String token,
    int profileId, {
    int limit = 50,
  }) {
    return ApiClient.sendJsonObject(
      () => ApiClient.httpClient.get(
        Uri.parse('$baseUrl/chat/messages?profile_id=$profileId&limit=$limit'),
        headers: ApiClient.headers(token: token),
      ),
      timeout: _kChatTimeout,
    );
  }
}
