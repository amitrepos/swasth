import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'flavor.dart';

class AppConfig {
  /// Resolved server host. Precedence:
  ///  1. `--dart-define=SERVER_HOST` at build time (explicit override, wins over everything)
  ///  2. `.env` file's `SERVER_HOST` (dev-time override for a specific checkout)
  ///  3. `Flavor.current.serverHost` (compile-time flavor value — primary source)
  ///  4. Hardcoded fallback (only reached if Flavor.current is not set, e.g. in a unit test)
  static String get serverHost {
    const explicitHost = String.fromEnvironment('SERVER_HOST');
    if (explicitHost.isNotEmpty) return _stripTrailingSlash(explicitHost);

    try {
      final envHost = dotenv.env['SERVER_HOST'] ?? '';
      if (envHost.isNotEmpty) return _stripTrailingSlash(envHost);
    } catch (_) {
      // dotenv not loaded (unit tests, etc.) — fall through.
    }

    try {
      return _stripTrailingSlash(Flavor.current.serverHost);
    } catch (_) {
      // Flavor not set (unit tests that bypass bootstrap) — fall through.
    }

    // Last-resort fallback — only reached in contrived test scenarios.
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
