import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/config/app_config.dart';

void main() {
  test('serverHost resolves to a valid http(s) URL', () {
    final host = AppConfig.serverHost;
    // Must be a valid http or https URL with a port
    final urlPattern = RegExp(r'^https?://.+:\d+$');
    expect(
      urlPattern.hasMatch(host),
      isTrue,
      reason: 'serverHost must be a valid http(s)://host:port URL, got: $host',
    );
  });

  test('apiBaseUrl ends with /api/auth', () {
    expect(
      AppConfig.apiBaseUrl.endsWith('/api/auth'),
      isTrue,
      reason: 'apiBaseUrl must end with /api/auth',
    );
  });
}
