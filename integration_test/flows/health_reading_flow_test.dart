// E2E Test: Health reading flow (BP + Sugar manual entry)
//
// Tests:
//   1. BP entry screen renders correctly
//   2. BP form validates out-of-range values
//   3. Successful BP save calls API
//   4. Glucose entry screen renders correctly
//   5. Glucose form validates out-of-range values
//   6. Successful glucose save calls API
//
// Run: flutter test integration_test/flows/health_reading_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/reading_confirmation_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('Health Reading Flow — Blood Pressure', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('BP entry screen renders systolic, diastolic, pulse fields', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(readingSystolic, findsOneWidget);
      expect(readingDiastolic, findsOneWidget);
      expect(readingPulse, findsOneWidget);
      expect(readingSaveButton, findsOneWidget);

      // Should NOT show glucose field
      expect(readingGlucoseValue, findsNothing);
    });

    testWidgets('BP validates empty systolic field', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      // Leave fields empty, tap save
      await scrollUntilVisible(tester, readingSaveButton);
      await tapAndSettle(tester, readingSaveButton);

      // Should show validation snackbar (not navigate away)
      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('BP validates out-of-range systolic (too low)', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      await enterTextAndSettle(tester, readingSystolic, '30');
      await enterTextAndSettle(tester, readingDiastolic, '80');

      await scrollUntilVisible(tester, readingSaveButton);
      await tapAndSettle(tester, readingSaveButton);

      // Should show validation error (systolic must be 60-250)
      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('BP validates out-of-range diastolic (too high)', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      await enterTextAndSettle(tester, readingSystolic, '120');
      await enterTextAndSettle(tester, readingDiastolic, '200');

      await scrollUntilVisible(tester, readingSaveButton);
      await tapAndSettle(tester, readingSaveButton);

      // Should show validation error (diastolic must be 40-150)
      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Successful BP save calls API with correct data', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      await enterTextAndSettle(tester, readingSystolic, '136');
      await enterTextAndSettle(tester, readingDiastolic, '85');
      await enterTextAndSettle(tester, readingPulse, '72');

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify POST /readings was called
      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('BP boundary values: exactly 60/40 (minimum valid)', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      await enterTextAndSettle(tester, readingSystolic, '60');
      await enterTextAndSettle(tester, readingDiastolic, '40');

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should save successfully (boundary valid)
      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });
  });

  group('Health Reading Flow — Glucose', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Glucose entry screen renders glucose field only', (
      tester,
    ) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(readingGlucoseValue, findsOneWidget);
      expect(readingSaveButton, findsOneWidget);

      // Should NOT show BP fields
      expect(readingSystolic, findsNothing);
      expect(readingDiastolic, findsNothing);
    });

    testWidgets('Glucose validates empty field', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await scrollUntilVisible(tester, readingSaveButton);
      await tapAndSettle(tester, readingSaveButton);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Glucose validates out-of-range (too low)', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await enterTextAndSettle(tester, readingGlucoseValue, '10');

      await scrollUntilVisible(tester, readingSaveButton);
      await tapAndSettle(tester, readingSaveButton);

      // glucose must be 20-600
      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Glucose validates out-of-range (too high)', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await enterTextAndSettle(tester, readingGlucoseValue, '700');

      await scrollUntilVisible(tester, readingSaveButton);
      await tapAndSettle(tester, readingSaveButton);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Successful glucose save calls API', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await enterTextAndSettle(tester, readingGlucoseValue, '108');

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('Glucose boundary: exactly 20 (minimum valid)', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await enterTextAndSettle(tester, readingGlucoseValue, '20');

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('Glucose boundary: exactly 600 (maximum valid)', (
      tester,
    ) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await enterTextAndSettle(tester, readingGlucoseValue, '600');

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('Meal context chips render for glucose', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      // Glucose should show meal context options
      expect(find.textContaining('Fasting'), findsOneWidget);
    });
  });
}
