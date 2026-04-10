// E2E Test: Meal logging flow
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/quick_select_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('Meal Logging — Quick Select', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Renders 3 primary meal buttons', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      expect(find.byType(QuickSelectScreen), findsOneWidget);
      expect(mealHighCarb, findsOneWidget);
      expect(mealLowCarb, findsOneWidget);
      expect(mealSweets, findsOneWidget);
    });

    testWidgets('Meal type chip shows auto-detected meal type', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      final hour = DateTime.now().hour;
      final expected = hour < 11
          ? 'Breakfast'
          : hour < 15
          ? 'Lunch'
          : hour < 18
          ? 'Snack'
          : 'Dinner';
      expect(find.textContaining(expected), findsOneWidget);
    });

    testWidgets('Tap Heavy meal calls API', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      await tester.tap(mealHighCarb);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/meals'), isTrue);
    });

    testWidgets('Tap Light meal calls API', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      await tester.tap(mealLowCarb);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/meals'), isTrue);
    });

    testWidgets('Tap Sweets calls API', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      await tester.tap(mealSweets);
      await pumpN(tester, frames: 20);

      expect(env.tracker.hasCalled('POST', '/meals'), isTrue);
    });

    testWidgets('"More options" reveals extra categories', (tester) async {
      env = await TestEnv.createAtMealSelect(tester);

      expect(find.textContaining('More options'), findsOneWidget);

      await tester.tap(find.textContaining('More options'));
      await pumpN(tester);

      expect(find.textContaining('Less options'), findsOneWidget);
    });

    testWidgets('detectMealType returns correct values', (tester) async {
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

    testWidgets('glucoseImpactFor maps all categories', (tester) async {
      expect(glucoseImpactFor('HIGH_CARB'), 'HIGH');
      expect(glucoseImpactFor('SWEETS'), 'VERY_HIGH');
      expect(glucoseImpactFor('MODERATE_CARB'), 'MODERATE');
      expect(glucoseImpactFor('LOW_CARB'), 'LOW');
      expect(glucoseImpactFor('HIGH_PROTEIN'), 'LOW');
      expect(glucoseImpactFor('UNKNOWN'), 'MODERATE');
    });
  });
}
