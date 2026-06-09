// Widget test: RegionService.refresh() fires post-login with auth token (NUO-135).
//
// Guards the fix in unified_login_screen.dart — accidental removal of
// `await RegionService.refresh()` would silently regress allowlist users.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:swasth_app/screens/unified_login_screen.dart';
import 'package:swasth_app/services/region_service.dart';

import '../helpers/mock_http.dart';
import '../helpers/test_app.dart';

void main() {
  tearDown(() => RegionService.setCacheForTest(null));

  testWidgets(
    'region re-fetched with auth token after login (CRITICAL-2)',
    (tester) async {
      // Pre-load a write-blocked cache — simulates allowlist user on VPN
      // who had their region checked before login (no token at that point).
      RegionService.setCacheForTest(const RegionInfo(
        countryCode: 'US',
        writeAllowed: false,
        source: 'ip',
      ));

      final env = await TestEnv.create(
        tester,
        startScreen: const UnifiedLoginScreen(),
        overrides: {
          // Skip the email-verification dialog so navigation reaches
          // SelectProfileScreen without manual dialog dismissal.
          'GET /me': http.Response(
            jsonEncode({
              'id': 1,
              'email': 'test@swasth.app',
              'full_name': 'Test User',
              'is_admin': false,
              'email_verified': true,
            }),
            200,
          ),
          // Return India-allowed so the cache is properly updated after refresh.
          'GET /public/region': http.Response(
            jsonEncode({
              'country_code': 'IN',
              'write_allowed': true,
              'source': 'ip',
            }),
            200,
          ),
        },
      );

      // Step 1: enter email → Continue
      await tester.enterText(
          find.byKey(const Key('login_email')), 'test@swasth.app');
      await pumpN(tester, frames: 3);
      await tester.tap(find.byKey(const Key('login_button')));
      await pumpN(tester, frames: 50);

      // Step 2: enter password → Login
      expect(find.byKey(const Key('login_password')), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('login_password')), 'Test1234!');
      await pumpN(tester, frames: 3);
      await tester.tap(find.byKey(const Key('login_button')));
      await pumpN(tester, frames: 50);

      // Verify: GET /public/region was called after login
      final regionCalls = env.tracker.calls
          .where((r) => r.method == 'GET' && r.url.path.endsWith('/public/region'))
          .toList();
      expect(
        regionCalls,
        isNotEmpty,
        reason: 'RegionService.refresh() must re-fetch /public/region post-login',
      );

      // Verify: the request carried the auth token (allowlist gate depends on this)
      final lastCall = regionCalls.last;
      final authValue = lastCall.headers.entries
          .firstWhere(
            (e) => e.key.toLowerCase() == 'authorization',
            orElse: () => const MapEntry('', ''),
          )
          .value;
      expect(
        authValue,
        equals('Bearer mock_token_123'),
        reason: 'region re-fetch must include saved auth token',
      );

      // Verify: cache updated — write is now allowed for the allowlisted user
      expect(RegionService.currentOrUnknown().writeAllowed, isTrue);

      env.dispose();
    },
  );
}
