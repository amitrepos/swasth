// E2E Test: Meal logging flow
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/quick_select_screen.dart';
import 'package:swasth_app/services/storage_service.dart';

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

  // Regression tests for the 2026-04-11 bug where tapping a specific
  // meal slot on the dashboard ("Breakfast", "Lunch", "Snack",
  // "Dinner") always saved the meal with the time-based meal type
  // from `detectMealType()` — so tapping "Breakfast" at 4pm saved
  // as SNACK. Fix was to plumb the tapped slot type through
  // MealSummaryCard → home_screen → modal → QuickSelectScreen and
  // use it on save instead of `detectMealType()`.
  group('Meal Logging — explicit meal type overrides time-based default', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets(
      'QuickSelectScreen with mealType=BREAKFAST saves BREAKFAST regardless of hour',
      (tester) async {
        // Skip the TestEnv.createAtMealSelect helper so we can pass
        // an explicit mealType — the helper constructs the screen
        // without one.
        StorageService.useInMemoryStorage();
        await StorageService().saveToken('mock_token_123');
        env = await TestEnv.create(
          tester,
          startScreen: const _InlineNavWrapper(
            child: QuickSelectScreen(profileId: 1, mealType: 'BREAKFAST'),
          ),
        );
        await pumpN(tester, frames: 5);

        await tester.tap(mealLowCarb);
        await pumpN(tester, frames: 20);

        final body = env.tracker.lastRequestBody('POST', '/meals');
        expect(
          body,
          isNotNull,
          reason: 'Tapping a meal button must POST to /meals',
        );
        expect(
          body!['meal_type'],
          equals('BREAKFAST'),
          reason:
              'Saved meal_type must be the value passed to QuickSelectScreen, '
              'not detectMealType() based on current hour',
        );
      },
    );

    testWidgets('QuickSelectScreen with mealType=LUNCH saves LUNCH', (
      tester,
    ) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      env = await TestEnv.create(
        tester,
        startScreen: const _InlineNavWrapper(
          child: QuickSelectScreen(profileId: 1, mealType: 'LUNCH'),
        ),
      );
      await pumpN(tester, frames: 5);

      await tester.tap(mealHighCarb);
      await pumpN(tester, frames: 20);

      final body = env.tracker.lastRequestBody('POST', '/meals');
      expect(body?['meal_type'], equals('LUNCH'));
    });

    testWidgets('QuickSelectScreen with mealType=DINNER saves DINNER', (
      tester,
    ) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      env = await TestEnv.create(
        tester,
        startScreen: const _InlineNavWrapper(
          child: QuickSelectScreen(profileId: 1, mealType: 'DINNER'),
        ),
      );
      await pumpN(tester, frames: 5);

      await tester.tap(mealSweets);
      await pumpN(tester, frames: 20);

      final body = env.tracker.lastRequestBody('POST', '/meals');
      expect(body?['meal_type'], equals('DINNER'));
    });

    testWidgets(
      'QuickSelectScreen without mealType still falls back to detectMealType()',
      (tester) async {
        // Backwards-compatibility: the generic "+" button and empty-state
        // CTA pass null, and the screen should preserve old behaviour
        // (wall-clock meal type). Without this, every user who opened
        // the modal from the "+" would need to pick a slot first.
        env = await TestEnv.createAtMealSelect(tester);

        await tester.tap(mealLowCarb);
        await pumpN(tester, frames: 20);

        final body = env.tracker.lastRequestBody('POST', '/meals');
        expect(body, isNotNull);
        // The fallback value depends on the wall clock — assert only
        // that it is one of the four valid values, not which one.
        expect(
          body!['meal_type'],
          isIn(['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER']),
          reason: 'Fallback must still populate a valid meal_type',
        );
      },
    );
  });
}

/// Minimal Navigator wrapper for tests that need to construct a
/// specific screen with non-default constructor arguments. The
/// existing `TestEnv.createAtMealSelect` helper hardcodes the
/// constructor, so tests that need to pass `mealType` use this
/// wrapper instead.
class _InlineNavWrapper extends StatefulWidget {
  final Widget child;
  const _InlineNavWrapper({required this.child});

  @override
  State<_InlineNavWrapper> createState() => _InlineNavWrapperState();
}

class _InlineNavWrapperState extends State<_InlineNavWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => widget.child,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Parent')));
  }
}
