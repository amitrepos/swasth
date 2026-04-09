// E2E Test: Authentication flow
//
// Tests the complete user journey:
//   1. Login screen renders correctly
//   2. Form validation catches bad input
//   3. Successful login navigates to profile selection
//   4. Registration link navigates to registration screen
//
// Run: flutter test integration_test/flows/auth_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/login_screen.dart';
import 'package:swasth_app/screens/registration_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('Auth Flow E2E', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Login screen renders all required elements', (tester) async {
      env = await TestEnv.createAtLogin(tester);

      // Verify login screen is displayed
      expect(find.byType(LoginScreen), findsOneWidget);

      // Verify all input fields exist
      expect(loginEmail, findsOneWidget);
      expect(loginPassword, findsOneWidget);
      expect(loginButton, findsOneWidget);
      expect(loginRegisterLink, findsOneWidget);

      // Verify forgot password link exists
      expect(find.textContaining('Forgot'), findsOneWidget);
    });

    testWidgets('Login form validates empty fields', (tester) async {
      env = await TestEnv.createAtLogin(tester);

      // Tap login with empty fields
      await tapAndSettle(tester, loginButton);

      // Validation errors should appear
      expect(find.textContaining('email'), findsWidgets);
      expect(find.textContaining('password'), findsWidgets);
    });

    testWidgets('Login form validates invalid email', (tester) async {
      env = await TestEnv.createAtLogin(tester);

      // Enter invalid email
      await enterTextAndSettle(tester, loginEmail, 'not-an-email');
      await enterTextAndSettle(tester, loginPassword, 'Test1234!');

      // Tap login
      await tapAndSettle(tester, loginButton);

      // Email validation error should appear
      expect(find.textContaining('valid email'), findsOneWidget);
    });

    testWidgets('Successful login navigates to profile selection', (
      tester,
    ) async {
      env = await TestEnv.createAtLogin(tester);

      // Enter valid credentials
      await enterTextAndSettle(tester, loginEmail, 'test@swasth.app');
      await enterTextAndSettle(tester, loginPassword, 'Test1234!');

      // Tap login
      await tester.tap(loginButton);
      await tester.pump(); // Start the async operation
      await tester.pump(const Duration(seconds: 1)); // Wait for API
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify API was called
      expect(env.tracker.hasCalled('POST', '/login'), isTrue);

      // Should navigate to profile selection
      expect(find.byType(SelectProfileScreen), findsOneWidget);
    });

    testWidgets('Register link navigates to registration screen', (
      tester,
    ) async {
      env = await TestEnv.createAtLogin(tester);

      // Tap register link
      await tapAndSettle(tester, loginRegisterLink);

      // Should navigate to registration screen
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });

    testWidgets('Registration screen renders all required fields', (
      tester,
    ) async {
      env = await TestEnv.createAtLogin(tester);

      // Navigate to registration
      await tapAndSettle(tester, loginRegisterLink);

      // Verify registration form fields
      expect(regFullName, findsOneWidget);
      expect(regEmail, findsOneWidget);
      expect(regPhone, findsOneWidget);
      expect(regPassword, findsOneWidget);

      // Scroll to find confirm password and submit
      await scrollUntilVisible(tester, regConfirmPassword);
      expect(regConfirmPassword, findsOneWidget);

      await scrollUntilVisible(tester, regSubmit);
      expect(regSubmit, findsOneWidget);
    });

    testWidgets('Registration validates empty required fields', (tester) async {
      env = await TestEnv.createAtLogin(tester);

      // Navigate to registration
      await tapAndSettle(tester, loginRegisterLink);

      // Scroll to submit button and tap
      await scrollUntilVisible(tester, regSubmit);
      await tapAndSettle(tester, regSubmit);

      // Should show validation errors (not navigate away)
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });
  });
}
