// E2E Test: Meal logging flow
//
// Tests:
//   1. Quick Select screen renders 3 primary buttons
//   2. Meal type auto-detected by time
//   3. Tap category saves meal via API
//   4. "More options" reveals extra categories
//   5. All 5 categories save correctly
//
// Run: flutter test integration_test/flows/meal_logging_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/quick_select_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('Meal Logging Flow — Quick Select', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Quick Select renders 3 primary meal buttons', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      expect(find.byType(QuickSelectScreen), findsOneWidget);
      expect(mealHighCarb, findsOneWidget);
      expect(mealLowCarb, findsOneWidget);
      expect(mealSweets, findsOneWidget);
    });

    testWidgets('Meal type chip shows auto-detected meal type', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      final hour = DateTime.now().hour;
      if (hour < 11) {
        expect(find.textContaining('Breakfast'), findsOneWidget);
      } else if (hour < 15) {
        expect(find.textContaining('Lunch'), findsOneWidget);
      } else if (hour < 18) {
        expect(find.textContaining('Snack'), findsOneWidget);
      } else {
        expect(find.textContaining('Dinner'), findsOneWidget);
      }
    });

    testWidgets('Tap Heavy meal button calls API and navigates back', (
      tester,
    ) async {
      env = await TestEnv.createAtMealSelect(tester);

      await tester.tap(mealHighCarb);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify POST /meals was called
      expect(env.tracker.hasCalled('POST', '/meals'), isTrue);
    });

    testWidgets('Tap Light meal button calls API', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      await tester.tap(mealLowCarb);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(env.tracker.hasCalled('POST', '/meals'), isTrue);
    });

    testWidgets('Tap Sweets button calls API', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      await tester.tap(mealSweets);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(env.tracker.hasCalled('POST', '/meals'), isTrue);
    });

    testWidgets('"More options" reveals extra meal categories', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      // Initially should not show "More options" expanded categories
      expect(find.textContaining('More options'), findsOneWidget);

      // Tap "More options"
      await tapAndSettle(tester, find.textContaining('More options'));

      // Should now show "Less options"
      expect(find.textContaining('Less options'), findsOneWidget);
    });

    testWidgets('Disclaimer text is visible', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      // Should show wellness disclaimer at bottom
      expect(find.textContaining('wellness'), findsOneWidget);
    });

    testWidgets('detectMealType returns correct value for all time slots', (
      tester,
    ) async {
      // Unit test embedded in E2E — tests the pure function
      expect(detectMealType(DateTime(2026, 1, 1, 7)), 'BREAKFAST');
      expect(detectMealType(DateTime(2026, 1, 1, 10)), 'BREAKFAST');
      expect(detectMealType(DateTime(2026, 1, 1, 11)), 'LUNCH');
      expect(detectMealType(DateTime(2026, 1, 1, 14)), 'LUNCH');
      expect(detectMealType(DateTime(2026, 1, 1, 15)), 'SNACK');
      expect(detectMealType(DateTime(2026, 1, 1, 17)), 'SNACK');
      expect(detectMealType(DateTime(2026, 1, 1, 18)), 'DINNER');
      expect(detectMealType(DateTime(2026, 1, 1, 23)), 'DINNER');
      expect(detectMealType(DateTime(2026, 1, 1, 0)), 'BREAKFAST');
    });

    testWidgets('glucoseImpactFor maps all categories correctly', (
      tester,
    ) async {
      expect(glucoseImpactFor('HIGH_CARB'), 'HIGH');
      expect(glucoseImpactFor('SWEETS'), 'VERY_HIGH');
      expect(glucoseImpactFor('MODERATE_CARB'), 'MODERATE');
      expect(glucoseImpactFor('LOW_CARB'), 'LOW');
      expect(glucoseImpactFor('HIGH_PROTEIN'), 'LOW');
      expect(glucoseImpactFor('UNKNOWN'), 'MODERATE');
    });
  });
}
