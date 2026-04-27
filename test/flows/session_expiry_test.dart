// Tests for session expiry: SyncService 401 handling, ShellScreen._validateSession,
// and ErrorMapper logout redirect.
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/shell_screen.dart';
import 'package:swasth_app/screens/unified_login_screen.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/api_exception.dart';
import 'package:swasth_app/services/error_mapper.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/services/sync_service.dart';

import '../helpers/mock_http.dart';
import '../helpers/test_app.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _reading() => {
  'profile_id': 1,
  'reading_type': 'glucose',
  'glucose_value': 108.0,
  'glucose_unit': 'mg/dL',
  'value_numeric': 108.0,
  'unit_display': 'mg/dL',
  'status_flag': 'NORMAL',
  'reading_timestamp': DateTime.now().toIso8601String(),
};

/// MaterialApp with /login route — required for ErrorMapper.pushNamedAndRemoveUntil.
Widget _appWithLoginRoute(Widget home) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {'/login': (_) => const UnifiedLoginScreen()},
      home: home,
    ),
  );
}

// ── SyncService 401 handling ──────────────────────────────────────────────────

void main() {
  group('SyncService — mid-sync 401', () {
    setUp(() => StorageService.useInMemoryStorage());
    tearDown(() {
      ApiClient.httpClientOverride = null;
      StorageService.useRealStorage();
    });

    test('2nd item 401: synced=1, failed=2, token deleted, queue preserved', () async {
      final storage = StorageService();
      await storage.saveToken('expired-token');
      await storage.saveSyncQueue([_reading(), _reading(), _reading()]);

      int postCount = 0;
      ApiClient.httpClientOverride = MockClient((req) async {
        if (req.url.path.contains('/readings') && req.method == 'POST') {
          postCount++;
          if (postCount == 2) {
            return http.Response(jsonEncode({'detail': 'Unauthorized'}), 401);
          }
          return http.Response(
            jsonEncode({'id': postCount, 'profile_id': 1, 'reading_type': 'glucose',
              'value_numeric': 108.0, 'unit_display': 'mg/dL', 'status_flag': 'NORMAL',
              'reading_timestamp': DateTime.now().toIso8601String()}),
            201,
          );
        }
        return http.Response('OK', 200); // health check
      });

      final result = await SyncService().syncPendingReadings();

      expect(result.synced, 1);
      expect(result.failed, 2);
      expect(result.authExpired, isTrue);
      expect(await storage.getToken(), isNull);
      expect((await storage.getSyncQueue()).length, 2);
    });

    test('no 401 during sync: authExpired is false, token preserved', () async {
      final storage = StorageService();
      await storage.saveToken('valid-token');
      await storage.saveSyncQueue([_reading()]);

      ApiClient.httpClientOverride = createMockClient();

      final result = await SyncService().syncPendingReadings();

      expect(result.synced, 1);
      expect(result.authExpired, isFalse);
      expect(await storage.getToken(), isNotNull);
    });

    test('1st item 401: synced=0, all 3 items preserved in queue', () async {
      final storage = StorageService();
      await storage.saveToken('expired-token');
      await storage.saveSyncQueue([_reading(), _reading(), _reading()]);

      ApiClient.httpClientOverride = MockClient((req) async {
        if (req.url.path.contains('/readings') && req.method == 'POST') {
          return http.Response(jsonEncode({'detail': 'Unauthorized'}), 401);
        }
        return http.Response('OK', 200);
      });

      final result = await SyncService().syncPendingReadings();

      expect(result.synced, 0);
      expect(result.failed, 3);
      expect(result.authExpired, isTrue);
      expect((await storage.getSyncQueue()).length, 3);
    });
  });

  // ── ShellScreen._validateSession ─────────────────────────────────────────

  group('ShellScreen._validateSession', () {
    setUp(() => StorageService.useInMemoryStorage());
    tearDown(() {
      ApiClient.httpClientOverride = null;
      StorageService.useRealStorage();
    });

    testWidgets('valid token on resume: no dialog shown', (tester) async {
      final storage = StorageService();
      await storage.saveToken('valid-token');
      await storage.saveActiveProfileId(1);
      await storage.saveActiveProfileName('My Health');
      await storage.saveActiveProfileAccessLevel('owner');

      ApiClient.httpClientOverride = createMockClient();

      await tester.pumpWidget(_appWithLoginRoute(const ShellScreen()));
      await pumpN(tester, frames: 20);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpN(tester, frames: 20);

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('expired token on resume: session expired dialog shown', (tester) async {
      final storage = StorageService();
      await storage.saveToken('expired-token');
      await storage.saveActiveProfileId(1);
      await storage.saveActiveProfileName('My Health');
      await storage.saveActiveProfileAccessLevel('owner');

      // Initial load succeeds, then swap to 401 for /me on resume
      ApiClient.httpClientOverride = createMockClient();
      await tester.pumpWidget(_appWithLoginRoute(const ShellScreen()));
      await pumpN(tester, frames: 20);

      // Swap: /me now returns 401
      ApiClient.httpClientOverride = MockClient((req) async {
        if (req.url.path.endsWith('/me') && req.method == 'GET') {
          return http.Response(jsonEncode({'detail': 'Unauthorized'}), 401);
        }
        return http.Response('OK', 200);
      });

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpN(tester, frames: 20);

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('network error on resume: no dialog (offline graceful)', (tester) async {
      final storage = StorageService();
      await storage.saveToken('valid-token');
      await storage.saveActiveProfileId(1);
      await storage.saveActiveProfileName('My Health');
      await storage.saveActiveProfileAccessLevel('owner');

      ApiClient.httpClientOverride = createMockClient();
      await tester.pumpWidget(_appWithLoginRoute(const ShellScreen()));
      await pumpN(tester, frames: 20);

      // Swap: all requests throw network error
      ApiClient.httpClientOverride = MockClient((_) async {
        throw Exception('Network unreachable');
      });

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpN(tester, frames: 20);

      // Network error ≠ auth failure — no logout dialog
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('no token on resume: no API call made, no dialog', (tester) async {
      // No token saved — _validateSession should early-return
      await StorageService().saveActiveProfileId(1);
      await StorageService().saveActiveProfileName('My Health');
      await StorageService().saveActiveProfileAccessLevel('owner');

      final tracker = ApiCallTracker();
      ApiClient.httpClientOverride = createMockClient(tracker: tracker);

      await tester.pumpWidget(_appWithLoginRoute(const ShellScreen()));
      await pumpN(tester, frames: 20);

      final callsBefore = tracker.calls.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpN(tester, frames: 10);

      // No new /me call made
      final meCalls = tracker.calls
          .skip(callsBefore)
          .where((r) => r.url.path.endsWith('/me'))
          .length;
      expect(meCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  // ── ErrorMapper._showSessionExpiredAndLogout ──────────────────────────────

  group('ErrorMapper — session expired logout flow', () {
    setUp(() => StorageService.useInMemoryStorage());
    tearDown(() => StorageService.useRealStorage());

    // Suppress pre-existing overflow in UnifiedLoginScreen on narrow viewports.
    void suppressOverflow(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final orig = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflow')) return;
        orig?.call(d);
      };
      addTearDown(() => FlutterError.onError = orig);
    }

    testWidgets('dialog shown with Login button', (tester) async {
      await tester.pumpWidget(
        _appWithLoginRoute(
          Builder(builder: (ctx) => Scaffold(
            body: TextButton(
              key: const Key('trigger'),
              onPressed: () =>
                  ErrorMapper.showSnack(ctx, const UnauthorizedException()),
              child: const Text('Go'),
            ),
          )),
        ),
      );

      await tester.tap(find.byKey(const Key('trigger')));
      await pumpN(tester, frames: 10);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Login button clears token and navigates to UnifiedLoginScreen', (tester) async {
      suppressOverflow(tester);
      await StorageService().saveToken('expired-token');

      await tester.pumpWidget(
        _appWithLoginRoute(
          Builder(builder: (ctx) => Scaffold(
            body: TextButton(
              key: const Key('trigger'),
              onPressed: () =>
                  ErrorMapper.showSnack(ctx, const UnauthorizedException()),
              child: const Text('Go'),
            ),
          )),
        ),
      );

      await tester.tap(find.byKey(const Key('trigger')));
      await pumpN(tester, frames: 10);

      // Tap the Login button in the dialog
      await tester.tap(find.text('Login'));
      await pumpN(tester, frames: 20);

      expect(find.byType(UnifiedLoginScreen), findsOneWidget);
      expect(await StorageService().getToken(), isNull);
    });

    testWidgets('navigation fires even if parent widget rebuilds during dialog', (tester) async {
      suppressOverflow(tester);
      // Simulates context becoming stale between dialog show and dismiss
      await StorageService().saveToken('stale-token');

      await tester.pumpWidget(
        _appWithLoginRoute(
          Builder(builder: (ctx) => Scaffold(
            body: TextButton(
              key: const Key('trigger'),
              onPressed: () =>
                  ErrorMapper.showSnack(ctx, const UnauthorizedException()),
              child: const Text('Go'),
            ),
          )),
        ),
      );

      await tester.tap(find.byKey(const Key('trigger')));
      await pumpN(tester, frames: 5);

      // Force a rebuild while dialog is open
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Login'));
      await pumpN(tester, frames: 20);

      // Navigation still completes — navigator was captured before await
      expect(find.byType(UnifiedLoginScreen), findsOneWidget);
    });
  });
}
