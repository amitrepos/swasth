import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Explicit override via --dart-define always wins.
  // Usage: flutter run --dart-define=SERVER_HOST=http://10.0.0.189:8000
  static const String _explicitHost = String.fromEnvironment('SERVER_HOST');

  // Backend port — override with --dart-define=SERVER_PORT=8000
  static const String _serverPort = String.fromEnvironment(
    'SERVER_PORT',
    defaultValue: '8000',
  );

  /// Resolved server host.
  ///  1. --dart-define=SERVER_HOST  (if provided)
  ///  2. Web: same hostname the browser loaded the app from, port [_serverPort]
  ///  3. Mobile fallback: http://10.0.2.2:<port> (Android emulator → host loopback)
  static String get serverHost {
    if (_explicitHost.isNotEmpty) return _explicitHost;

    if (kIsWeb) {
      // On web the app is served from the dev machine, so the browser's
      // hostname is already the correct address for the backend.
      return Uri.base.replace(port: int.parse(_serverPort), path: '').toString().replaceAll(RegExp(r'/+$'), '');
    }

    // Android emulator maps 10.0.2.2 → host machine's localhost.
    // For physical devices, pass --dart-define=SERVER_HOST=http://<LAN-IP>:8000
    return 'http://10.0.2.2:$_serverPort';
  }

  // Complete API base URL
  static String get apiBaseUrl => '$serverHost/api/auth';

  // Helper method to build URLs
  static String buildUrl(String endpoint) {
    return '$apiBaseUrl$endpoint';
  }

  // Print current configuration (for debugging)
  static void printConfig() {
    print('=== App Configuration ===');
    print('Server Host: $serverHost');
    print('API Base URL: $apiBaseUrl');
    print('========================');
  }
}
