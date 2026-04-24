// E2E Test: Authentication flow
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/unified_login_screen.dart';
import 'package:swasth_app/screens/registration_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

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
      await pumpN(tester, frames: 50);

      // Assert that send-email-verification was called BEFORE navigation
      expect(env.tracker.hasCalled('POST', '/send-email-verification'), isTrue);

      // Should now be on EmailVerificationScreen
      expect(find.byKey(const Key('email_verify_otp_field')), findsOneWidget);
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
  });
}
