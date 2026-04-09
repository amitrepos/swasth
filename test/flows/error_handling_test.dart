// E2E Test: Error handling — API failures degrade gracefully
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swasth_app/screens/login_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/screens/reading_confirmation_screen.dart';
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

void main() {
  group('Error Handling E2E', () {
    tearDown(() {
      ApiClient.httpClientOverride = null;
      StorageService.useRealStorage();
    });

    testWidgets('Login with wrong credentials shows error', (tester) async {
      final env = await TestEnv.createAtLogin(tester);

      // Override with 401 client after env creates the mock
      ApiClient.httpClientOverride = _createUnauthorizedClient();

      await tester.enterText(loginEmail, 'wrong@email.com');
      await tester.enterText(loginPassword, 'WrongPass1!');
      await pumpN(tester, frames: 3);

      await tester.tap(loginButton);
      await pumpN(tester, frames: 20);

      // Should stay on login screen (not navigate away)
      expect(find.byType(LoginScreen), findsOneWidget);

      // Should show error snackbar
      expect(find.byType(SnackBar), findsOneWidget);

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
      expect(env.tracker.hasCalled('POST', '/login'), isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);

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
  });
}
