import 'dart:convert';
import 'package:http/http.dart' as http;

/// Shared HTTP utilities used by all API service classes.
class ApiClient {
  /// Builds standard JSON headers, with an optional Bearer token.
  static Map<String, String> headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Extracts the `detail` field from a non-success response body.
  /// Falls back to [fallback] if the field is missing or the body is malformed.
  static String errorDetail(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['detail'] as String?) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
