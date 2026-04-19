// Unit tests for ErrorMapper.
//
// Two concerns:
//   1. userMessage() — pure translation of exception type → localized string.
//      Asserts we never leak a raw Dart exception to a patient.
//   2. showSnack() — when an UnauthorizedException is caught anywhere in the
//      app, ErrorMapper clears the session and resets navigation to /login.
//      That's the 401 interceptor — losing it = users stuck tapping retry
//      on a revoked token.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/api_exception.dart';
import 'package:swasth_app/services/error_mapper.dart';
import 'package:swasth_app/services/storage_service.dart';

/// Pumps a minimal MaterialApp wired with real AppLocalizations + a named
/// route table so ErrorMapper.showSnack can navigate to '/login' and we
/// can observe the result.
Future<void> _pumpHarness(
  WidgetTester tester, {
  required Widget child,
  Map<String, WidgetBuilder>? routes,
  String locale = 'en',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {
        '/login': (_) => const Scaffold(body: Text('LOGIN-SCREEN')),
        ...?routes,
      },
      home: child,
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    // Use in-memory storage so showSnack's clearAll() doesn't touch real
    // secure storage (which fails under flutter_test anyway).
    StorageService.useInMemoryStorage();
  });

  group('ErrorMapper.userMessage', () {
    late AppLocalizations en;

    setUp(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('NetworkException → errNetwork', () {
      expect(
        ErrorMapper.userMessage(en, const NetworkException()),
        en.errNetwork,
      );
    });

    test('UnauthorizedException → errSessionExpired', () {
      expect(
        ErrorMapper.userMessage(en, const UnauthorizedException()),
        en.errSessionExpired,
      );
    });

    test('ServerException → errServer (ignores any detail)', () {
      expect(
        ErrorMapper.userMessage(en, const ServerException('raw 500 body')),
        en.errServer,
      );
      // Crucially — the "raw 500 body" string MUST NOT leak.
      expect(
        ErrorMapper.userMessage(en, const ServerException('raw 500 body')),
        isNot(contains('raw 500 body')),
      );
    });

    test('ValidationException surfaces server detail when non-empty', () {
      expect(
        ErrorMapper.userMessage(en, const ValidationException('Invalid OTP')),
        'Invalid OTP',
      );
    });

    test('ValidationException falls back to errGeneric when detail empty', () {
      expect(
        ErrorMapper.userMessage(en, const ValidationException('')),
        en.errGeneric,
      );
    });

    test('unknown Dart exception → errGeneric (never leaks toString)', () {
      final msg = ErrorMapper.userMessage(en, StateError('internal: foo'));
      expect(msg, en.errGeneric);
      expect(msg, isNot(contains('StateError')));
      expect(msg, isNot(contains('foo')));
    });

    test('SocketException-like raw string → errGeneric (defensive)', () {
      // Screens should never throw a raw SocketException past ApiClient, but
      // if some legacy catch-rethrows one, ErrorMapper must not leak it.
      final msg = ErrorMapper.userMessage(en, Exception('SocketException'));
      expect(msg, en.errGeneric);
      expect(msg, isNot(contains('SocketException')));
    });
  });

  group('ErrorMapper.userMessage — Hindi locale', () {
    test('NetworkException returns Hindi string', () async {
      final hi = await AppLocalizations.delegate.load(const Locale('hi'));
      final msg = ErrorMapper.userMessage(hi, const NetworkException());
      expect(msg, hi.errNetwork);
      // Sanity: not the English fallback.
      expect(msg, contains('इंटरनेट'));
    });

    test('UnauthorizedException returns Hindi string', () async {
      final hi = await AppLocalizations.delegate.load(const Locale('hi'));
      expect(
        ErrorMapper.userMessage(hi, const UnauthorizedException()),
        hi.errSessionExpired,
      );
    });
  });

  group('ErrorMapper.showSnack', () {
    testWidgets('shows snackbar with localized network message', (
      tester,
    ) async {
      final key = GlobalKey();
      await _pumpHarness(
        tester,
        child: Scaffold(
          key: key,
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () =>
                  ErrorMapper.showSnack(ctx, const NetworkException()),
              child: const Text('TAP'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('TAP'));
      await tester.pump(); // SnackBar animation frame
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(en.errNetwork), findsOneWidget);
    });

    testWidgets(
      'UnauthorizedException shows modal, clears session on OK, routes to /login',
      (tester) async {
        // Seed a token so we can assert it's cleared after showSnack.
        await StorageService().saveToken('seed-token');
        expect(await StorageService().getToken(), 'seed-token');

        await _pumpHarness(
          tester,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () =>
                    ErrorMapper.showSnack(ctx, const UnauthorizedException()),
                child: const Text('TAP'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('TAP'));
        // Dialog animation + async dispatch
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Modal is showing — NOT yet navigated away. Token still present
        // because we haven't acknowledged.
        final en = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(en.errSessionExpired), findsAtLeast(1));
        expect(await StorageService().getToken(), 'seed-token');
        expect(find.text('LOGIN-SCREEN'), findsNothing);

        // User taps "Login" button on the dialog.
        await tester.tap(find.widgetWithText(TextButton, en.loginButton));
        // Drain: dialog dismiss + clearAll + pushNamedAndRemoveUntil.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Now token is wiped and login screen is the sole surviving route.
        expect(await StorageService().getToken(), isNull);
        expect(find.text('LOGIN-SCREEN'), findsOneWidget);
      },
    );

    testWidgets(
      'concurrent UnauthorizedExceptions do not crash or double-nav',
      (tester) async {
        // Priya's risk path: two API calls in flight both return 401
        // (e.g. home screen fans out 2 parallel requests). Both fire
        // ErrorMapper.showSnack, both try to clearAll + nav. Expected:
        // no crash, token cleared, single login screen present.
        await StorageService().saveToken('seed-token');

        await _pumpHarness(
          tester,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  // Fire both without awaiting — simulates two in-flight
                  // requests both surfacing 401 at the same microtask tick.
                  final a = ErrorMapper.showSnack(
                    ctx,
                    const UnauthorizedException(),
                  );
                  final b = ErrorMapper.showSnack(
                    ctx,
                    const UnauthorizedException(),
                  );
                  await Future.wait([a, b]);
                },
                child: const Text('TAP'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('TAP'));
        // Drain modal + acknowledge + nav
        final en = await AppLocalizations.delegate.load(const Locale('en'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        // Dismiss every modal the concurrent calls raised. showDialog doesn't
        // dedupe; we just make sure the acknowledge cycle drains cleanly.
        while (find.byType(AlertDialog).evaluate().isNotEmpty) {
          await tester.tap(
            find.widgetWithText(TextButton, en.loginButton).first,
          );
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        }
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(tester.takeException(), isNull);
        expect(await StorageService().getToken(), isNull);
        expect(find.text('LOGIN-SCREEN'), findsOneWidget);
      },
    );

    testWidgets('non-401 error does NOT navigate or clear token', (
      tester,
    ) async {
      await StorageService().saveToken('keep-me');

      await _pumpHarness(
        tester,
        child: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () =>
                  ErrorMapper.showSnack(ctx, const ServerException()),
              child: const Text('TAP'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('TAP'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(await StorageService().getToken(), 'keep-me');
      // Login screen must NOT be visible — we stayed on the original route.
      expect(find.text('LOGIN-SCREEN'), findsNothing);
    });
  });
}
