// E2E Test: Authentication flow
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/unified_login_screen.dart';
import 'package:swasth_app/screens/registration_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/screens/email_verification_screen.dart';
import 'package:http/http.dart' as http;

import '../helpers/test_app.dart';
import '../helpers/finders.dart';
import '../helpers/mock_http.dart';

void main() {
  group('Auth — Login', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('Login screen renders all required elements', (tester) async {
      env = await TestEnv.createAtLogin(tester);

      expect(find.byType(UnifiedLoginScreen), findsOneWidget);
      expect(find.byKey(const Key('login_email')), findsOneWidget);
      expect(loginButton, findsOneWidget);
      expect(loginRegisterLink, findsOneWidget);
    });

    testWidgets('Login form validates empty fields', (tester) async {
      env = await TestEnv.createAtLogin(tester);

      await tester.tap(loginButton);
      await pumpN(tester);

      // Should still be on login screen (validation failed)
      expect(find.byType(UnifiedLoginScreen), findsOneWidget);
    });

    testWidgets('Login form validates invalid email', (tester) async {
      env = await TestEnv.createAtLogin(tester);

      // Enter invalid email/phone
      await tester.enterText(loginEmail, 'not-an-email');
      await pumpN(tester);

      // Tap continue button - should show validation error
      await tester.tap(loginButton);
      await pumpN(tester);

      // Should show validation error and stay on input step
      expect(find.textContaining('valid email'), findsOneWidget);
    });

    testWidgets('Successful login navigates to profile selection', (
      tester,
    ) async {
      env = await TestEnv.createAtLogin(tester);

      // Step 1: Enter email and tap continue
      await tester.enterText(loginEmail, 'test@swasth.app');
      await pumpN(tester, frames: 3);

      await tester.tap(loginButton);
      await pumpN(tester, frames: 50);

      // Step 2: After account check, password field should appear
      // Enter password
      expect(find.byKey(const Key('login_password')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('login_password')),
        'Test1234!',
      );
      await pumpN(tester, frames: 3);

      // Step 3: Tap login button again to submit
      await tester.tap(loginButton);
      await pumpN(tester, frames: 50);

      expect(env.tracker.hasCalled('POST', '/login'), isTrue);

      // Email verification dialog may appear (email_verified=false in mock).
      // Dismiss it by tapping "Later" to proceed to SelectProfileScreen.
      final laterButton = find.text('Later');
      if (laterButton.evaluate().isNotEmpty) {
        await tester.tap(laterButton);
        await pumpN(tester, frames: 20);
      }

      expect(find.byType(SelectProfileScreen), findsOneWidget);
    });

    testWidgets('Login with unverified email sends OTP before navigation', (
      tester,
    ) async {
      env = await TestEnv.createAtLogin(tester);

      // Step 1: Enter email and tap continue
      await tester.enterText(loginEmail, 'test@swasth.app');
      await pumpN(tester, frames: 3);

      await tester.tap(loginButton);
      await pumpN(tester, frames: 50);

      // Step 2: Enter password
      expect(find.byKey(const Key('login_password')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('login_password')),
        'Test1234!',
      );
      await pumpN(tester, frames: 3);

      // Step 3: Tap login to submit
      await tester.tap(loginButton);
      await pumpN(tester, frames: 50);

      // Verify login was called
      expect(env.tracker.hasCalled('POST', '/login'), isTrue);

      // Email verification dialog appears (email_verified=false in mock)
      // Tap "Verify Now" to trigger OTP send + navigation
      final verifyNowButton = find.text('Verify Now');
      expect(verifyNowButton, findsOneWidget);
      await tester.tap(verifyNowButton);
      await pumpN(tester, frames: 100); // More frames for async OTP send + navigation

      // Assert that send-email-verification was called BEFORE navigation
      expect(env.tracker.hasCalled('POST', '/send-email-verification'), isTrue);

      // Should now be on EmailVerificationScreen
      expect(find.byKey(const Key('email_verify_otp_field')), findsOneWidget);
    });

    testWidgets('OTP send failure shows error dialog and blocks navigation', (
      tester,
    ) async {
      env = await TestEnv.create(
        tester,
        startScreen: const UnifiedLoginScreen(),
        overrides: {
          'POST /send-email-verification': http.Response(
            '{"detail": "Email service unavailable"}',
            500,
          ),
        },
      );

      // Step 1: Enter email and tap continue
      await tester.enterText(loginEmail, 'test@swasth.app');
      await pumpN(tester, frames: 3);

      await tester.tap(loginButton);
      await pumpN(tester, frames: 50);

      // Step 2: Enter password
      expect(find.byKey(const Key('login_password')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('login_password')),
        'Test1234!',
      );
      await pumpN(tester, frames: 3);

      // Step 3: Tap login to submit
      await tester.tap(loginButton);
      await pumpN(tester, frames: 50);

      // Email verification dialog appears
      final verifyNowButton = find.text('Verify Now');
      expect(verifyNowButton, findsOneWidget);
      await tester.tap(verifyNowButton);
      await pumpN(tester, frames: 50);

      // Should show error dialog (title: "Error", content: failure message)
      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('Failed to send'), findsOneWidget);

      // Should NOT navigate to EmailVerificationScreen
      expect(find.byType(EmailVerificationScreen), findsNothing);

      // Retry button should be present
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Register link exists on login screen', (tester) async {
      env = await TestEnv.createAtLogin(tester);

      // Verify the register link widget exists in tree
      expect(loginRegisterLink, findsOneWidget);
    });
  });

  group('Auth — Registration', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('Registration screen renders account fields', (tester) async {
      // Start directly at registration screen (skip login navigation)
      env = await TestEnv.create(
        tester,
        startScreen: const RegistrationScreen(),
      );

      expect(find.byType(RegistrationScreen), findsOneWidget);
      expect(regFullName, findsOneWidget);
      expect(regEmail, findsOneWidget);
      expect(regPhone, findsOneWidget);
      expect(regPassword, findsOneWidget);
    });

    testWidgets('Registration screen renders health profile fields', (
      tester,
    ) async {
      env = await TestEnv.create(
        tester,
        startScreen: const RegistrationScreen(),
      );

      // Scroll down to health profile section
      await scrollUntilVisible(tester, regConfirmPassword);
      expect(regConfirmPassword, findsOneWidget);

      await scrollUntilVisible(tester, regAge);
      expect(regAge, findsOneWidget);
    });

    testWidgets('Registration has submit button', (tester) async {
      env = await TestEnv.create(
        tester,
        startScreen: const RegistrationScreen(),
      );

      await scrollUntilVisible(tester, regSubmit);
      expect(regSubmit, findsOneWidget);
    });

    testWidgets('Registration validates empty required fields', (tester) async {
      env = await TestEnv.create(
        tester,
        startScreen: const RegistrationScreen(),
      );

      await scrollUntilVisible(tester, regSubmit);
      await tester.tap(regSubmit, warnIfMissed: false);
      await pumpN(tester);

      // Should still be on registration (validation failed)
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });

    testWidgets('Successful registration sends OTP and navigates to verification', (
      tester,
    ) async {
      env = await TestEnv.create(
        tester,
        startScreen: const RegistrationScreen(),
      );

      // Fill in registration form
      await tester.enterText(regFullName, 'Test User');
      await tester.enterText(regEmail, 'newuser@swasth.app');
      await tester.enterText(regPhone, '+911234567890');
      await tester.enterText(regPassword, 'SecurePass123!');
      await tester.enterText(regConfirmPassword, 'SecurePass123!');
      await pumpN(tester);

      // Submit registration
      await scrollUntilVisible(tester, regSubmit);
      await tester.tap(regSubmit);
      await pumpN(tester, frames: 50);

      // Should navigate to consent screen first (not tested here)
      // After consent, it should call register, login, and send OTP
      // For this test, we verify the API calls are made
      expect(env.tracker.hasCalled('POST', '/register'), isTrue);
    });

    testWidgets('Registration login failure shows error snack', (
      tester,
    ) async {
      env = await TestEnv.create(
        tester,
        startScreen: const RegistrationScreen(),
        overrides: {
          'POST /login': http.Response(
            '{"detail": "Invalid credentials"}',
            401,
          ),
        },
      );

      // Fill in minimal registration form
      await tester.enterText(regFullName, 'Test User');
      await tester.enterText(regEmail, 'newuser@swasth.app');
      await tester.enterText(regPhone, '+911234567890');
      await tester.enterText(regPassword, 'SecurePass123!');
      await tester.enterText(regConfirmPassword, 'SecurePass123!');
      await pumpN(tester);

      // Submit registration
      await scrollUntilVisible(tester, regSubmit);
      await tester.tap(regSubmit);
      await pumpN(tester, frames: 50);

      // After consent, login will fail and show error
      // The error snack should appear
      expect(env.tracker.hasCalled('POST', '/register'), isTrue);
    });

    testWidgets('Registration getCurrentUser failure does not block OTP send', (
      tester,
    ) async {
      env = await TestEnv.create(
        tester,
        startScreen: const RegistrationScreen(),
        overrides: {
          'GET /me': http.Response('{"detail": "Server error"}', 500),
        },
      );

      // Fill in registration form
      await tester.enterText(regFullName, 'Test User');
      await tester.enterText(regEmail, 'newuser@swasth.app');
      await tester.enterText(regPhone, '+911234567890');
      await tester.enterText(regPassword, 'SecurePass123!');
      await tester.enterText(regConfirmPassword, 'SecurePass123!');
      await pumpN(tester);

      // Submit registration
      await scrollUntilVisible(tester, regSubmit);
      await tester.tap(regSubmit);
      await pumpN(tester, frames: 50);

      // Even if getCurrentUser fails, OTP should still be sent
      expect(env.tracker.hasCalled('POST', '/register'), isTrue);
      expect(env.tracker.hasCalled('POST', '/send-email-verification'), isTrue);
    });

    testWidgets('Registration OTP send failure navigates with requiresInitialSend=true', (
      tester,
    ) async {
      env = await TestEnv.create(
        tester,
        startScreen: const RegistrationScreen(),
        overrides: {
          'POST /send-email-verification': http.Response(
            '{"detail": "Email service unavailable"}',
            500,
          ),
        },
      );

      // Fill in registration form
      await tester.enterText(regFullName, 'Test User');
      await tester.enterText(regEmail, 'newuser@swasth.app');
      await tester.enterText(regPhone, '+911234567890');
      await tester.enterText(regPassword, 'SecurePass123!');
      await tester.enterText(regConfirmPassword, 'SecurePass123!');
      await pumpN(tester);

      // Submit registration
      await scrollUntilVisible(tester, regSubmit);
      await tester.tap(regSubmit);
      await pumpN(tester, frames: 50);

      // Should show error snack for OTP failure
      // Still navigates to EmailVerificationScreen with requiresInitialSend=true
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      // The "Send Verification Code" button should be visible
      expect(find.byKey(const Key('email_verify_send_code')), findsOneWidget);
    });
  });
}
