// E2E Test: Dashboard display — all sections render correctly
//
// Tests:
//   1. Login screen elements all render
//   2. Profile selection screen renders profiles
//   3. Quick select screen renders all elements
//   4. BP entry screen renders all fields
//   5. Glucose entry screen renders glucose field
//   6. No red error bars or overflow errors
//
// Run: flutter test integration_test/flows/dashboard_display_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/login_screen.dart';
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

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(loginEmail, findsOneWidget);
      expect(loginPassword, findsOneWidget);
      expect(loginButton, findsOneWidget);
      expect(loginRegisterLink, findsOneWidget);

      // App branding visible
      expect(find.byIcon(Icons.health_and_safety), findsOneWidget);

      // No error widgets
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Profile selection: renders profile list after login', (
      tester,
    ) async {
      env = await TestEnv.createAtProfileSelect(tester);

      // Wait for profiles to load from mock API
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(SelectProfileScreen), findsOneWidget);

      // Should show "My Health" profile from mock
      expect(find.textContaining('My Health'), findsWidgets);

      // Should show add profile button
      expect(find.byIcon(Icons.add), findsOneWidget);

      // No error widgets
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('BP entry: all fields present with correct labels', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);

      // BP-specific fields
      expect(readingSystolic, findsOneWidget);
      expect(readingDiastolic, findsOneWidget);
      expect(readingPulse, findsOneWidget);

      // Save button
      expect(readingSaveButton, findsOneWidget);

      // Time picker area
      expect(find.byIcon(Icons.access_time), findsOneWidget);

      // No glucose field for BP screen
      expect(readingGlucoseValue, findsNothing);

      // No error widgets
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Glucose entry: glucose field present, no BP fields', (
      tester,
    ) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);

      // Glucose-specific field
      expect(readingGlucoseValue, findsOneWidget);

      // No BP fields
      expect(readingSystolic, findsNothing);
      expect(readingDiastolic, findsNothing);

      // Meal context chips (fasting, before/after meal)
      expect(find.textContaining('Fasting'), findsOneWidget);

      // No error widgets
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Quick Select: 3 buttons, meal type chip, disclaimer', (
      tester,
    ) async {
      env = await TestEnv.createAtMealSelect(tester);

      expect(find.byType(QuickSelectScreen), findsOneWidget);

      // 3 primary meal buttons
      expect(mealHighCarb, findsOneWidget);
      expect(mealLowCarb, findsOneWidget);
      expect(mealSweets, findsOneWidget);

      // Meal type chip (Breakfast/Lunch/Snack/Dinner)
      final hour = DateTime.now().hour;
      final expectedType = hour < 11
          ? 'Breakfast'
          : hour < 15
          ? 'Lunch'
          : hour < 18
          ? 'Snack'
          : 'Dinner';
      expect(find.textContaining(expectedType), findsOneWidget);

      // More options link
      expect(find.textContaining('More'), findsOneWidget);

      // No error widgets
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Login → Profile Select navigation works end-to-end', (
      tester,
    ) async {
      env = await TestEnv.createAtLogin(tester);

      // Fill login form
      await enterTextAndSettle(tester, loginEmail, 'test@swasth.app');
      await enterTextAndSettle(tester, loginPassword, 'Test1234!');

      // Submit
      await tester.tap(loginButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should be on profile selection now
      expect(find.byType(SelectProfileScreen), findsOneWidget);

      // Wait for profiles to load
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should show profile card
      expect(find.textContaining('My Health'), findsWidgets);

      // No error widgets anywhere in the flow
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });
}
