// E2E Test: Health reading flow (BP + Sugar manual entry)
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/reading_confirmation_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('Health Reading — Blood Pressure', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('BP screen renders systolic, diastolic, pulse fields', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(readingSystolic, findsOneWidget);
      expect(readingDiastolic, findsOneWidget);
      expect(readingPulse, findsOneWidget);
      expect(readingSaveButton, findsOneWidget);
      expect(readingGlucoseValue, findsNothing); // no glucose field for BP
    });

    testWidgets('BP validates empty systolic', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('BP validates out-of-range systolic (too low)', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '30');
      await tester.enterText(readingDiastolic, '80');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('BP validates out-of-range diastolic (too high)', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '120');
      await tester.enterText(readingDiastolic, '200');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Successful BP save calls API', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '136');
      await tester.enterText(readingDiastolic, '85');
      await tester.enterText(readingPulse, '72');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('BP boundary: exactly 60/40 (minimum valid)', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '60');
      await tester.enterText(readingDiastolic, '40');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });
  });

  group('Health Reading — Glucose', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Glucose screen renders glucose field only', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      expect(find.byType(ReadingConfirmationScreen), findsOneWidget);
      expect(readingGlucoseValue, findsOneWidget);
      expect(readingSaveButton, findsOneWidget);
      expect(readingSystolic, findsNothing); // no BP fields
      expect(readingDiastolic, findsNothing);
    });

    testWidgets('Glucose validates empty field', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Glucose validates out-of-range (too low)', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await tester.enterText(readingGlucoseValue, '10');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Glucose validates out-of-range (too high)', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await tester.enterText(readingGlucoseValue, '700');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Successful glucose save calls API', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await tester.enterText(readingGlucoseValue, '108');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('Glucose boundary: exactly 20 (minimum valid)', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await tester.enterText(readingGlucoseValue, '20');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('Glucose boundary: exactly 600 (maximum valid)', (
      tester,
    ) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await tester.enterText(readingGlucoseValue, '600');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('Meal context chips render for glucose', (tester) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      expect(find.textContaining('Fasting'), findsOneWidget);
    });
  });
}
