// E2E Test: Dashboard display — all sections render correctly
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/unified_login_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/screens/reading_confirmation_screen.dart';
import 'package:swasth_app/screens/quick_select_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('Dashboard Display E2E', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Login screen: all interactive elements present', (
      tester,
    ) async {
      env = await TestEnv.createAtLogin(tester);

      expect(find.byType(UnifiedLoginScreen), findsOneWidget);
      expect(loginEmail, findsOneWidget);
      // Password field is conditionally shown, but key should be defined
      expect(loginButton, findsOneWidget);
      expect(loginRegisterLink, findsOneWidget);
      expect(find.byIcon(Icons.health_and_safety), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Profile selection: renders profile list', (tester) async {
      env = await TestEnv.createAtProfileSelect(tester);

      expect(find.byType(SelectProfileScreen), findsOneWidget);
      expect(find.textContaining('My Health'), findsWidgets);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('BP entry: all fields present', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(readingSystolic, findsOneWidget);
      expect(readingDiastolic, findsOneWidget);
      expect(readingPulse, findsOneWidget);
      expect(readingSaveButton, findsOneWidget);
      expect(readingGlucoseValue, findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Glucose entry: glucose field present, no BP fields', (
      tester,
    ) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(readingGlucoseValue, findsOneWidget);
      expect(readingSystolic, findsNothing);
      expect(readingDiastolic, findsNothing);
      expect(find.textContaining('Fasting'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Quick Select: 3 buttons + meal type chip', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      expect(find.byType(QuickSelectScreen), findsOneWidget);
      expect(mealHighCarb, findsOneWidget);
      expect(mealLowCarb, findsOneWidget);
      expect(mealSweets, findsOneWidget);
      expect(find.textContaining('More'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Login → Profile Select navigation end-to-end', (tester) async {
      env = await TestEnv.createAtLogin(tester);

      // Step 1: Enter email and tap continue
      await tester.enterText(loginEmail, 'test@swasth.app');
      await pumpN(tester, frames: 3);

      await tester.tap(loginButton);
      await pumpN(tester, frames: 30);

      // Step 2: After account check, password field should appear
      // Enter password
      expect(find.byKey(const Key('login_password')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('login_password')),
        'Test1234!',
      );
      await pumpN(tester, frames: 3);

      // Step 3: Tap login button to submit
      await tester.tap(loginButton);
      await pumpN(tester, frames: 30);

      // Email verification dialog may appear (email_verified=false in mock).
      // Dismiss it by tapping "Later" to proceed to SelectProfileScreen.
      final laterButton = find.text('Later');
      if (laterButton.evaluate().isNotEmpty) {
        await tester.tap(laterButton);
        await pumpN(tester, frames: 20);
      }

      expect(find.byType(SelectProfileScreen), findsOneWidget);

      // Wait for profiles to load
      await pumpN(tester, frames: 15);
      expect(find.textContaining('My Health'), findsWidgets);
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });
}
