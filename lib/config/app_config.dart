class AppConfig {
  // Load from --dart-define or use defaults
  // Usage: flutter run --dart-define=SERVER_HOST=http://10.0.0.189:8000
  static const String serverHost = String.fromEnvironment(
    'SERVER_HOST',
    defaultValue: 'http://localhost:8000',
  );

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
