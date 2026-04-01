import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Resolved server host.
  ///  1. --dart-define=SERVER_HOST (if provided at build time)
  ///  2. .env file SERVER_HOST variable
  static String get serverHost {
    // Explicit override via --dart-define always wins.
    const explicitHost = String.fromEnvironment('SERVER_HOST');
    if (explicitHost.isNotEmpty) return _stripTrailingSlash(explicitHost);

    // Read from .env file (may not be initialized in tests)
    try {
      final envHost = dotenv.env['SERVER_HOST'] ?? '';
      if (envHost.isNotEmpty) return _stripTrailingSlash(envHost);
    } catch (_) {
      // dotenv not loaded — fall through to default
    }

    // Fallback (should not happen if .env is configured)
    return 'http://10.0.2.2:8000';
  }

  static String _stripTrailingSlash(String url) {
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  // Complete API base URL
  static String get apiBaseUrl => '$serverHost/api/auth';

  // Helper method to build URLs
  static String buildUrl(String endpoint) {
    return '$apiBaseUrl$endpoint';
  }
}
