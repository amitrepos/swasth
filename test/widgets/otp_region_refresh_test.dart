// Widget test: RegionService.refresh() fires post-OTP-login with auth token (NUO-135 CRITICAL-1).
//
// Guards phone_otp_verification_screen.dart — accidental removal of
// `await RegionService.refresh()` from _verifyOTP() has no other CI signal.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:swasth_app/screens/phone_otp_verification_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/services/region_service.dart';

import '../helpers/mock_http.dart';
import '../helpers/test_app.dart';
import '../helpers/test_constants.dart';

void main() {
  tearDown(() => RegionService.setCacheForTest(null));

  testWidgets(
    'region re-fetched with auth token after OTP verification (CRITICAL-1)',
    (tester) async {
      // Pre-load write-blocked cache — simulates allowlist user on VPN
      // who was checked unauthenticated (no token) before OTP login.
      RegionService.setCacheForTest(const RegionInfo(
        countryCode: 'US',
        writeAllowed: false,
        source: 'ip',
      ));

      final env = await TestEnv.create(
        tester,
        startScreen: const PhoneOTPVerificationScreen(phoneNumber: '+919876543210'),
        overrides: {
          'POST /phone-otp/verify': http.Response(
            jsonEncode({
              'access_token': TestConstants.mockToken,
              'token_type': 'bearer',
              'is_new_user': false,
            }),
            200,
          ),
          'GET /me': http.Response(
            jsonEncode({
              'id': 1,
              'email': 'otp@swasth.app',
              'full_name': 'OTP User',
              'is_admin': false,
              'email_verified': true,
            }),
            200,
          ),
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

      // Pre-condition: VPN user is write-blocked before OTP login
      expect(
        RegionService.currentOrUnknown().writeAllowed,
        isFalse,
        reason: 'pre-condition: allowlist user must start read-only before OTP login',
      );

      // Submit OTP
      await tester.enterText(find.byKey(const Key('phone_otp_field')), '123456');
      await pumpN(tester, frames: 3);
      await tester.tap(find.byKey(const Key('phone_otp_verify_button')));
      await pumpN(tester, frames: 50);

      // Assert: GET /public/region was called after OTP verification
      final regionCalls = env.tracker.calls
          .where((r) =>
              r.method == 'GET' && r.url.path.endsWith('/public/region'))
          .toList();
      expect(
        regionCalls,
        isNotEmpty,
        reason:
            'RegionService.refresh() must re-fetch /public/region after OTP login',
      );

      // Assert: the region request carried the saved auth token
      final auth = regionCalls.last.headers.entries
          .firstWhere(
            (e) => e.key.toLowerCase() == 'authorization',
            orElse: () => const MapEntry('', ''),
          )
          .value;
      expect(
        auth,
        equals('Bearer ${TestConstants.mockToken}'),
        reason: 'region re-fetch must carry auth token so VPN allowlist fires',
      );

      // Assert: cache is now write-allowed (allowlist fired)
      expect(RegionService.currentOrUnknown().writeAllowed, isTrue);

      // Assert: OTP login completed — user reached profile selection
      expect(find.byType(SelectProfileScreen), findsOneWidget);

      env.dispose();
    },
  );
}
