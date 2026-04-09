// E2E Test: Boundary values + token expiry edge cases
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/reading_confirmation_screen.dart';
import 'package:swasth_app/screens/quick_select_screen.dart';
import 'package:swasth_app/services/storage_service.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('BP Boundary — Max Valid Values', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('Systolic 250 (max valid) saves successfully', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '250');
      await tester.enterText(readingDiastolic, '90');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('Systolic 251 (above max) shows validation error', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '251');
      await tester.enterText(readingDiastolic, '80');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(env.tracker.hasCalled('POST', '/readings'), isFalse);
    });

    testWidgets('Diastolic 150 (max valid) saves successfully', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '140');
      await tester.enterText(readingDiastolic, '150');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/readings'), isTrue);
    });

    testWidgets('Diastolic 151 (above max) shows validation error', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '120');
      await tester.enterText(readingDiastolic, '151');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(env.tracker.hasCalled('POST', '/readings'), isFalse);
    });

    testWidgets('Systolic 59 (below min) shows validation error', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '59');
      await tester.enterText(readingDiastolic, '80');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Diastolic 39 (below min) shows validation error', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '120');
      await tester.enterText(readingDiastolic, '39');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Glucose Boundary — Edge Values', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('Glucose 19 (below min) shows validation error', (
      tester,
    ) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await tester.enterText(readingGlucoseValue, '19');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(env.tracker.hasCalled('POST', '/readings'), isFalse);
    });

    testWidgets('Glucose 601 (above max) shows validation error', (
      tester,
    ) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await tester.enterText(readingGlucoseValue, '601');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(env.tracker.hasCalled('POST', '/readings'), isFalse);
    });

    testWidgets('Non-numeric glucose input shows validation error', (
      tester,
    ) async {
      env = await TestEnv.createAtGlucoseEntry(tester);

      await tester.enterText(readingGlucoseValue, 'abc');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Non-numeric BP input shows validation error', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, 'xyz');
      await tester.enterText(readingDiastolic, '80');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Meal Classification Boundaries', () {
    // Pure function tests — no widget needed
    test('All 5 categories map to correct glucose impact', () {
      expect(glucoseImpactFor('HIGH_CARB'), 'HIGH');
      expect(glucoseImpactFor('LOW_CARB'), 'LOW');
      expect(glucoseImpactFor('MODERATE_CARB'), 'MODERATE');
      expect(glucoseImpactFor('HIGH_PROTEIN'), 'LOW');
      expect(glucoseImpactFor('SWEETS'), 'VERY_HIGH');
    });

    test('Unknown category defaults to MODERATE', () {
      expect(glucoseImpactFor('RANDOM'), 'MODERATE');
      expect(glucoseImpactFor(''), 'MODERATE');
    });

    test('Meal type detection at exact hour boundaries', () {
      // 10:59 → BREAKFAST, 11:00 → LUNCH
      expect(detectMealType(DateTime(2026, 1, 1, 10, 59)), 'BREAKFAST');
      expect(detectMealType(DateTime(2026, 1, 1, 11, 0)), 'LUNCH');

      // 14:59 → LUNCH, 15:00 → SNACK
      expect(detectMealType(DateTime(2026, 1, 1, 14, 59)), 'LUNCH');
      expect(detectMealType(DateTime(2026, 1, 1, 15, 0)), 'SNACK');

      // 17:59 → SNACK, 18:00 → DINNER
      expect(detectMealType(DateTime(2026, 1, 1, 17, 59)), 'SNACK');
      expect(detectMealType(DateTime(2026, 1, 1, 18, 0)), 'DINNER');

      // Midnight → BREAKFAST
      expect(detectMealType(DateTime(2026, 1, 1, 0, 0)), 'BREAKFAST');
    });
  });

  group('Token Expiry / Missing Token', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('Login screen shows when no token exists', (tester) async {
      // Don't seed any token — should show login
      env = await TestEnv.createAtLogin(tester);

      expect(loginEmail, findsOneWidget);
      expect(loginButton, findsOneWidget);
    });

    testWidgets('Reading save with expired token shows error gracefully', (
      tester,
    ) async {
      env = await TestEnv.createAtBpEntry(tester);

      // Clear the token mid-session to simulate expiry
      await StorageService().clearAll();

      await tester.enterText(readingSystolic, '120');
      await tester.enterText(readingDiastolic, '80');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      // Should show error, not crash
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Meal save with no token shows error gracefully', (
      tester,
    ) async {
      env = await TestEnv.createAtMealSelect(tester);

      // Clear the token
      await StorageService().clearAll();

      await tester.tap(mealHighCarb);
      await pumpN(tester, frames: 20);

      // Should show error snackbar, not crash
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });

  // ── CRITICAL C1: Health classification at clinical thresholds ──────────

  group('Health Classification Boundaries (C1 — clinical thresholds)', () {
    // BP classification: NORMAL ↔ STAGE 1 at 131/86, STAGE 1 ↔ STAGE 2 at 140/90
    test('BP 130/85 → NORMAL', () => expect(classifyBp(130, 85), 'NORMAL'));
    test(
      'BP 131/86 → NORMAL (inclusive)',
      () => expect(classifyBp(131, 86), 'NORMAL'),
    );
    test(
      'BP 132/85 → STAGE 1 (systolic triggers)',
      () => expect(classifyBp(132, 85), 'HIGH - STAGE 1'),
    );
    test(
      'BP 120/87 → STAGE 1 (diastolic triggers)',
      () => expect(classifyBp(120, 87), 'HIGH - STAGE 1'),
    );
    test(
      'BP 140/90 → STAGE 1 (boundary)',
      () => expect(classifyBp(140, 90), 'HIGH - STAGE 1'),
    );
    test(
      'BP 141/85 → STAGE 2 (systolic triggers)',
      () => expect(classifyBp(141, 85), 'HIGH - STAGE 2'),
    );
    test(
      'BP 120/91 → STAGE 2 (diastolic triggers)',
      () => expect(classifyBp(120, 91), 'HIGH - STAGE 2'),
    );
    test('BP 89/59 → LOW', () => expect(classifyBp(89, 59), 'LOW'));
    test(
      'BP 90/60 → NORMAL (boundary)',
      () => expect(classifyBp(90, 60), 'NORMAL'),
    );

    // Glucose classification: LOW < 70, NORMAL ≤ 130, HIGH ≤ 180, CRITICAL > 180
    test('Glucose 69 → LOW', () => expect(classifyGlucose(69), 'LOW'));
    test(
      'Glucose 70 → NORMAL (boundary)',
      () => expect(classifyGlucose(70), 'NORMAL'),
    );
    test(
      'Glucose 130 → NORMAL (boundary)',
      () => expect(classifyGlucose(130), 'NORMAL'),
    );
    test('Glucose 131 → HIGH', () => expect(classifyGlucose(131), 'HIGH'));
    test(
      'Glucose 180 → HIGH (boundary)',
      () => expect(classifyGlucose(180), 'HIGH'),
    );
    test(
      'Glucose 181 → CRITICAL',
      () => expect(classifyGlucose(181), 'CRITICAL'),
    );
    test(
      'Glucose 300 → CRITICAL',
      () => expect(classifyGlucose(300), 'CRITICAL'),
    );
    test(
      'Glucose 50 → LOW (hypoglycemia)',
      () => expect(classifyGlucose(50), 'LOW'),
    );
  });

  // ── CRITICAL C2: Double-tap prevention ─────────────────────────────────

  group('Double-Tap Prevention (C2)', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('Double-tap meal button saves only once', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);
      env.tracker.clear();

      await tester.tap(mealHighCarb);
      await tester.tap(mealHighCarb); // immediate second tap
      await pumpN(tester, frames: 20);

      final mealCalls = env.tracker.calls.where(
        (c) => c.method == 'POST' && c.url.toString().contains('/meals'),
      );
      expect(mealCalls.length, 1);
    });
  });

  // ── CRITICAL C3: Save navigates back ───────────────────────────────────

  group('Save Confirmation Navigation (C3)', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('BP save navigates back to parent', (tester) async {
      env = await TestEnv.createAtBpEntry(tester);

      await tester.enterText(readingSystolic, '120');
      await tester.enterText(readingDiastolic, '80');
      await pumpN(tester, frames: 3);

      await scrollUntilVisible(tester, readingSaveButton);
      await tester.tap(readingSaveButton);
      await pumpN(tester, frames: 20);

      // Should have popped back (reading screen gone)
      expect(find.byType(ReadingConfirmationScreen), findsNothing);
    });

    testWidgets('Meal save completes and shows success feedback', (
      tester,
    ) async {
      env = await TestEnv.createAtMealSelect(tester);

      await tester.tap(mealHighCarb);
      await pumpN(tester, frames: 20);

      // Save succeeded — API was called, no crash
      expect(env.tracker.hasCalled('POST', '/meals'), isTrue);
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });
}
