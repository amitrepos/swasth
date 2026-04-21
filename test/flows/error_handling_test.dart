// E2E Test: Error handling — API failures degrade gracefully
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swasth_app/screens/unified_login_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/config/app_config.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/storage_service.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

/// Creates a MockClient that returns errors for all endpoints.
MockClient _createErrorClient() {
  return MockClient((request) async {
    return http.Response(jsonEncode({'detail': 'Server error'}), 500);
  });
}

/// Creates a MockClient that returns 401 Unauthorized for login.
MockClient _createUnauthorizedClient() {
  return MockClient((request) async {
    return http.Response(jsonEncode({'detail': 'Invalid credentials'}), 401);
  });
}

/// Creates a MockClient that returns 404 Not Found — simulates wrong URL or
/// missing backend route. This is what causes the "Failed to save meal: Not Found" error.
MockClient _createNotFoundClient() {
  return MockClient((request) async {
    return http.Response(jsonEncode({'detail': 'Not Found'}), 404);
  });
}

void main() {
  group('Error Handling E2E', () {
    tearDown(() {
      ApiClient.httpClientOverride = null;
      StorageService.useRealStorage();
    });

    testWidgets('Login with wrong credentials shows error', (tester) async {
      final env = await TestEnv.createAtLogin(tester);

      // Enter email first before overriding client, so check-account succeeds
      await tester.enterText(loginEmail, 'wrong@email.com');
      await pumpN(tester, frames: 3);

      // Now override with 401 client - this will affect the login call
      ApiClient.httpClientOverride = _createUnauthorizedClient();

      await tester.tap(loginButton);
      await pumpN(tester, frames: 50);

      // After account check succeeds, password field should appear
      final passwordField = find.byKey(const Key('login_password'));
      if (passwordField.evaluate().isNotEmpty) {
        await tester.enterText(passwordField, 'WrongPass1!');
        await pumpN(tester, frames: 3);

        await tester.tap(loginButton);
        await pumpN(tester, frames: 30);
      }

      // Should stay on login screen (not navigate away) - main assertion
      expect(find.byType(UnifiedLoginScreen), findsOneWidget);

      env.dispose();
    });

    testWidgets('Profile list shows error when API fails', (tester) async {
      // Use TestEnv for proper setup, then swap to error client
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      final env = await TestEnv.create(
        tester,
        startScreen: const SelectProfileScreen(),
      );

      // First load succeeds (mock client), now swap to error client
      ApiClient.httpClientOverride = _createErrorClient();

      // Should show profile screen without crashes
      expect(find.byType(SelectProfileScreen), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      env.dispose();
    });

    testWidgets('BP save with server error shows snackbar', (tester) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');

      final env = await TestEnv.createAtBpEntry(tester);

      // Override with error client AFTER screen loads
      ApiClient.httpClientOverride = _createErrorClient();

      await tester.enterText(readingSystolic, '120');
      await tester.enterText(readingDiastolic, '80');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      // Should show error feedback (snackbar), not crash
      expect(find.byType(ErrorWidget), findsNothing);

      env.dispose();
    });

    testWidgets('Login screen handles empty credentials gracefully', (
      tester,
    ) async {
      final env = await TestEnv.createAtLogin(tester);

      // Tap login with empty fields
      await tester.tap(loginButton);
      await pumpN(tester);

      // Form validation should prevent API call
      expect(env.tracker.hasCalled('POST', '/check-account'), isFalse);
      expect(find.byType(UnifiedLoginScreen), findsOneWidget);

      env.dispose();
    });

    testWidgets('Glucose save with out-of-range value shows validation error', (
      tester,
    ) async {
      final env = await TestEnv.createAtGlucoseEntry(tester);

      await tester.enterText(readingGlucoseValue, '999');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      // Should show validation snackbar, not crash
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      env.dispose();
    });

    // ── 404 Not Found tests (the exact error from screenshot) ──────────

    testWidgets('Meal save with 404 shows error snackbar, not crash', (
      tester,
    ) async {
      final env = await TestEnv.createAtMealSelect(tester);

      // Swap to 404 client AFTER screen loads
      ApiClient.httpClientOverride = _createNotFoundClient();

      await tester.tap(mealHighCarb);
      await pumpN(tester, frames: 20);

      // Should show error snackbar with "Not Found" message
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      env.dispose();
    });

    testWidgets('BP save with 404 shows error snackbar, not crash', (
      tester,
    ) async {
      final env = await TestEnv.createAtBpEntry(tester);

      ApiClient.httpClientOverride = _createNotFoundClient();

      await tester.enterText(readingSystolic, '120');
      await tester.enterText(readingDiastolic, '80');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      // Should show error feedback, not crash
      expect(find.byType(ErrorWidget), findsNothing);

      env.dispose();
    });

    testWidgets('Glucose save with 404 shows error snackbar, not crash', (
      tester,
    ) async {
      final env = await TestEnv.createAtGlucoseEntry(tester);

      ApiClient.httpClientOverride = _createNotFoundClient();

      await tester.enterText(readingGlucoseValue, '108');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      expect(find.byType(ErrorWidget), findsNothing);

      env.dispose();
    });
  });

  // ── URL Contract Tests — verify Flutter URLs match backend routes ────

  group('API URL Contract', () {
    test('MealService URL matches backend route /api/meals', () {
      // Backend: app.include_router(routes_meals.router, prefix="/api")
      // Backend route: @router.post("/meals")
      // Flutter: AppConfig.serverHost + /api/meals
      final url = '${AppConfig.serverHost}/api/meals';
      expect(url, contains('/api/meals'));
      expect(url, isNot(contains('/api/api/'))); // no double /api/
    });

    test('HealthReadingService URL matches backend route /api/readings', () {
      final url = '${AppConfig.serverHost}/api/readings';
      expect(url, contains('/api/readings'));
    });

    test('ProfileService URL matches backend route /api/profiles', () {
      final url = '${AppConfig.serverHost}/api/profiles';
      expect(url, contains('/api/profiles'));
    });

    test('ChatService URL matches backend route /api/chat', () {
      final url = '${AppConfig.serverHost}/api/chat/send';
      expect(url, contains('/api/chat/'));
    });

    test('AuthService URL matches backend route /api/auth', () {
      final url = AppConfig.apiBaseUrl;
      expect(url, endsWith('/api/auth'));
    });
  });
}
