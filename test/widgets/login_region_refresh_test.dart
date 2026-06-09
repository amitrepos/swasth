// Widget tests: RegionService.refresh() behavior during email login (NUO-135).
//
// CRITICAL-2: region re-fetched with auth token after email login (core fix guard)
// MEDIUM-3:   pre-condition assertion — write-blocked state verified before login
// MEDIUM-2:   login completes when region refresh fails (fail-open guarantee)
// MEDIUM-1:   login completes within frame budget when region is slow (2G scenario)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/screens/unified_login_screen.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/region_service.dart';
import 'package:swasth_app/services/storage_service.dart';

import '../helpers/mock_http.dart';
import '../helpers/test_app.dart';
import '../helpers/test_constants.dart';

http.Response _meVerified() => http.Response(
      jsonEncode({
        'id': 1,
        'email': 'test@swasth.app',
        'full_name': 'Test User',
        'is_admin': false,
        'email_verified': true,
      }),
      200,
    );

http.Response _regionIndia() => http.Response(
      jsonEncode({'country_code': 'IN', 'write_allowed': true, 'source': 'ip'}),
      200,
    );

Future<void> _doEmailLogin(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const Key('login_email')), 'test@swasth.app');
  await pumpN(tester, frames: 3);
  await tester.tap(find.byKey(const Key('login_button')));
  await pumpN(tester, frames: 50);

  await tester.enterText(
      find.byKey(const Key('login_password')), 'Test1234!');
  await pumpN(tester, frames: 3);
  await tester.tap(find.byKey(const Key('login_button')));
  await pumpN(tester, frames: 50);
}

void main() {
  tearDown(() => RegionService.setCacheForTest(null));

  // ── CRITICAL-2 + MEDIUM-3 ─────────────────────────────────────────────────
  testWidgets(
    'region re-fetched with auth token after login (CRITICAL-2)',
    (tester) async {
      RegionService.setCacheForTest(const RegionInfo(
        countryCode: 'US',
        writeAllowed: false,
        source: 'ip',
      ));

      final env = await TestEnv.create(
        tester,
        startScreen: const UnifiedLoginScreen(),
        overrides: {
          'GET /me': _meVerified(),
          'GET /public/region': _regionIndia(),
        },
      );

      // MEDIUM-3: assert write is actually blocked before login so the
      // post-login assertion can't pass vacuously.
      expect(
        RegionService.currentOrUnknown().writeAllowed,
        isFalse,
        reason: 'pre-condition: cache must be write-blocked before login',
      );

      await _doEmailLogin(tester);

      final regionCalls = env.tracker.calls
          .where((r) =>
              r.method == 'GET' && r.url.path.endsWith('/public/region'))
          .toList();
      expect(
        regionCalls,
        isNotEmpty,
        reason: 'RegionService.refresh() must re-fetch /public/region post-login',
      );

      final authValue = regionCalls.last.headers.entries
          .firstWhere(
            (e) => e.key.toLowerCase() == 'authorization',
            orElse: () => const MapEntry('', ''),
          )
          .value;
      expect(
        authValue,
        equals('Bearer ${TestConstants.mockToken}'),
        reason: 'region re-fetch must include saved auth token',
      );

      expect(RegionService.currentOrUnknown().writeAllowed, isTrue);
      env.dispose();
    },
  );

  // ── MEDIUM-2 ──────────────────────────────────────────────────────────────
  testWidgets(
    'login navigates to SelectProfileScreen when region refresh fails (MEDIUM-2)',
    (tester) async {
      final env = await TestEnv.create(
        tester,
        startScreen: const UnifiedLoginScreen(),
        overrides: {
          'GET /me': _meVerified(),
          // 500 → sendJsonObject throws ServerException → _fetchAndCache catch
          // → RegionInfo.unknown (writeAllowed = true, fail-open)
          'GET /public/region': http.Response(
            jsonEncode({'detail': 'internal server error'}),
            500,
          ),
        },
      );

      await _doEmailLogin(tester);

      // Login must complete — user reaches SelectProfileScreen despite region error
      expect(
        find.byType(SelectProfileScreen),
        findsOneWidget,
        reason: 'login must not be blocked by region refresh failure',
      );

      // Region must fail open so the user is not locked out
      expect(
        RegionService.currentOrUnknown().writeAllowed,
        isTrue,
        reason: 'failing region refresh must fail-open, not lock the user out',
      );

      env.dispose();
    },
  );

  // ── MEDIUM-1 ──────────────────────────────────────────────────────────────
  testWidgets(
    'login completes within frame budget when region is slow (MEDIUM-1)',
    (tester) async {
      // Custom setup — TestEnv.create cannot inject Future.delayed into overrides.
      // We need direct client control to simulate 2G latency on the region endpoint.
      // pumpN uses 100 ms/frame, so a 500 ms region delay resolves by frame 5 of 50.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      StorageService.useInMemoryStorage();
      final origErr = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflow')) return;
        origErr?.call(d);
      };

      ApiClient.httpClientOverride = MockClient((request) async {
        final path = request.url.path;
        final method = request.method;

        if (method == 'GET' && path.endsWith('/public/region')) {
          await Future.delayed(const Duration(milliseconds: 500));
          return http.Response(
            jsonEncode({
              'country_code': 'UNKNOWN',
              'write_allowed': true,
              'source': 'unknown',
            }),
            200,
          );
        }
        if (method == 'POST' && path.endsWith('/check-account')) {
          return http.Response(
            jsonEncode({'exists': true, 'login_method': 'email_password'}), 200);
        }
        if (method == 'POST' && path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'access_token': TestConstants.mockToken,
              'token_type': 'bearer',
            }),
            200,
          );
        }
        if (method == 'GET' && path.endsWith('/me')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'email': 'test@swasth.app',
              'full_name': 'Test User',
              'is_admin': false,
              'email_verified': true,
            }),
            200,
          );
        }
        if (method == 'GET' && path.endsWith('/profiles')) {
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'name': 'My Health',
                'relationship': 'myself',
                'access_level': 'owner',
                'age': 65,
                'gender': 'Male',
                'phone_number': '919876543210',
                'created_at': '2026-01-01T00:00:00Z',
                'updated_at': '2026-01-01T00:00:00Z',
              }
            ]),
            200,
          );
        }
        return http.Response(jsonEncode({'detail': 'not found'}), 404);
      });

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const UnifiedLoginScreen(),
      ));
      await pumpN(tester, frames: 5);

      await _doEmailLogin(tester);

      expect(
        find.byType(SelectProfileScreen),
        findsOneWidget,
        reason: 'login must not freeze when region refresh is slow',
      );

      // Cleanup (no TestEnv.dispose available)
      ApiClient.httpClientOverride = null;
      StorageService.useRealStorage();
      FlutterError.onError = origErr;
    },
  );
}
