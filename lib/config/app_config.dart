import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'flavor.dart';

class AppConfig {
  /// Resolved server host.
  ///
  /// **Release builds (APK/AAB): flavor is the sole source of truth.**
  /// A production-flavor build always hits the production backend; a staging
  /// build always hits staging. `.env` and `--dart-define=SERVER_HOST` are
  /// IGNORED in release so a stray `.env` on a developer's machine (or a
  /// fat-fingered `--dart-define` at build time) can never cross-wire a
  /// release APK to the wrong backend. This is health data — an APK that
  /// lies about its environment is a safety issue, not a config nit.
  ///
  /// **Debug builds only**, the legacy override chain applies:
  ///   1. `--dart-define=SERVER_HOST=...` (explicit build-time override)
  ///   2. `.env` file's `SERVER_HOST` (dev checkout default)
  ///   3. `Flavor.current.serverHost` (fallback)
  static String get serverHost {
    if (kReleaseMode) {
      try {
        return _stripTrailingSlash(Flavor.current.serverHost);
      } catch (_) {
        // Flavor unset in a release build is a bug — fail loud rather than
        // silently default to an emulator URL.
        throw StateError(
          'AppConfig.serverHost accessed in release mode before Flavor.set() — '
          'every release entry point must call bootstrap(Flavor.xxx).',
        );
      }
    }

    const explicitHost = String.fromEnvironment('SERVER_HOST');
    if (explicitHost.isNotEmpty) return _stripTrailingSlash(explicitHost);

    try {
      final envHost = dotenv.env['SERVER_HOST'] ?? '';
      if (envHost.isNotEmpty) return _stripTrailingSlash(envHost);
    } catch (_) {
      // dotenv not loaded (unit tests etc.) — fall through.
    }

    try {
      return _stripTrailingSlash(Flavor.current.serverHost);
    } catch (_) {
      // Flavor not set (unit tests that bypass bootstrap) — fall through.
    }

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
