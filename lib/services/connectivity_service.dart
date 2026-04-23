import 'dart:async';
import 'dart:io';

import '../config/app_config.dart';
import 'api_client.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  /// Number of retry attempts before declaring offline
  static const int _maxRetries = 3;

  /// Timeout per request attempt (8s handles slow 3G networks)
  static const Duration _requestTimeout = Duration(seconds: 8);

  /// Delay between retry attempts
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Returns true if the backend server is reachable.
  ///
  /// Uses retry logic to handle transient network issues:
  /// - 3 retry attempts before declaring offline
  /// - 8 second timeout per attempt (good for slow networks)
  /// - 500ms delay between retries
  Future<bool> isServerReachable() async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await ApiClient.httpClient
            .get(Uri.parse('${AppConfig.serverHost}/health'))
            .timeout(_requestTimeout);

        // Server is reachable if we get any response < 500
        if (response.statusCode < 500) {
          return true;
        }

        // Server returned 5xx, but it's still reachable
        return true;
      } on SocketException {
        // Network unreachable - retry
        if (attempt == _maxRetries) return false;
      } on TimeoutException {
        // Request timed out - retry
        if (attempt == _maxRetries) return false;
      } on HandshakeException {
        // SSL/TLS error - retry (might be temporary)
        if (attempt == _maxRetries) return false;
      } on HttpException {
        // HTTP error - retry
        if (attempt == _maxRetries) return false;
      } catch (_) {
        // Unknown error - retry
        if (attempt == _maxRetries) return false;
      }

      // Wait before retry (except on last attempt)
      if (attempt < _maxRetries) {
        await Future.delayed(_retryDelay);
      }
    }

    return false;
  }
}
