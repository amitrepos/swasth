// Unit tests for SupportService.
//
// Why these tests matter: this service feeds the web "Contact Us" footer.
// A regression that returns null email or strips the WhatsApp/phone numbers
// would silently hide the support card — visitors then have no way to reach
// us pre-login. We cover happy path, partial config, empty config, and
// the explicit "no auth header" guarantee (the endpoint is public, and
// leaking a JWT to an unauthenticated route is a security finding).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/api_exception.dart';
import 'package:swasth_app/services/support_service.dart';

http.Response _ok(Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  tearDown(() {
    ApiClient.httpClientOverride = null;
  });

  group('SupportService.fetchContacts', () {
    test('parses all three fields when fully configured', () async {
      ApiClient.httpClientOverride = MockClient((req) async {
        expect(req.url.path, endsWith('/api/public/support'));
        return _ok({
          'email': 'help@example.com',
          'whatsapp_number': '919876543210',
          'phone_number': '+919876543210',
        });
      });

      final result = await SupportService().fetchContacts();
      expect(result.email, 'help@example.com');
      expect(result.whatsappNumber, '919876543210');
      expect(result.phoneNumber, '+919876543210');
    });

    test('falls back to default email when server returns null', () async {
      // Defense-in-depth: even if the backend somehow returns a null
      // email (misconfigured Settings, bad merge), the widget must
      // still render an email button.
      ApiClient.httpClientOverride = MockClient((_) async => _ok({
            'email': null,
            'whatsapp_number': null,
            'phone_number': null,
          }));

      final result = await SupportService().fetchContacts();
      expect(result.email, 'support@swasth.health');
      expect(result.whatsappNumber, isNull);
      expect(result.phoneNumber, isNull);
    });

    test('treats blank strings as null', () async {
      // The backend can return "" if .env has SUPPORT_WHATSAPP_NUMBER=
      // (empty value). The widget hides the WhatsApp/phone button only
      // when the value is null, so the service normalizes "" → null
      // to avoid a button that opens wa.me/ (empty).
      ApiClient.httpClientOverride = MockClient((_) async => _ok({
            'email': 'help@example.com',
            'whatsapp_number': '   ',
            'phone_number': '',
          }));

      final result = await SupportService().fetchContacts();
      expect(result.whatsappNumber, isNull);
      expect(result.phoneNumber, isNull);
    });

    test('does NOT send an Authorization header (public endpoint)', () async {
      // Security: this endpoint is unauthenticated. Sending a JWT to a
      // public surface leaks claims/expiry and is a finding in its own
      // right. Hardcoded so a future maintainer can't accidentally
      // re-introduce auth headers.
      String? authHeader = 'sentinel-not-overwritten';
      ApiClient.httpClientOverride = MockClient((req) async {
        authHeader = req.headers['Authorization'];
        return _ok({
          'email': 'help@example.com',
          'whatsapp_number': null,
          'phone_number': null,
        });
      });

      await SupportService().fetchContacts();
      expect(authHeader, isNull);
    });

    test('throws ServerException when backend is unreachable', () async {
      // Surfaces typed exceptions from ApiClient so the widget can
      // safely render "hide the section" on error.
      ApiClient.httpClientOverride = MockClient(
        (_) async => http.Response('boom', 500),
      );

      expect(
        () => SupportService().fetchContacts(),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
