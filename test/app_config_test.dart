import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/config/app_config.dart';

void main() {
  test('serverHost default must be an IP address, not localhost', () {
    final host = AppConfig.serverHost;
    // Reject localhost — physical devices cannot reach it
    expect(
      host.contains('localhost'),
      isFalse,
      reason: 'serverHost must not use localhost — use a real IP for device testing',
    );
    expect(
      host.contains('127.0.0.1'),
      isFalse,
      reason: 'serverHost must not use 127.0.0.1 — use a real IP for device testing',
    );
    // Must look like http(s)://x.x.x.x:port
    final ipPattern = RegExp(r'https?://\d+\.\d+\.\d+\.\d+:\d+');
    expect(
      ipPattern.hasMatch(host),
      isTrue,
      reason: 'serverHost must be a valid http(s)://IP:port address, got: $host',
    );
  });
}
