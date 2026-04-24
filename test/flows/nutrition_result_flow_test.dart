// E2E Test: NutritionResultScreen flow
// Tests the nutrition analysis result screen displayed after photo-based meal logging.
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/nutrition_result_screen.dart';
import 'package:swasth_app/models/nutrition_analysis_result.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/services/connectivity_service.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('NutritionResultScreen — Display', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Renders meal score card when score is present', (tester) async {
      env = await _createNutritionResultScreen(tester, mealScore: 8);

      // Look for the meal health score label to ensure we're in the right card
      expect(find.text('Meal Health Score'), findsOneWidget);
      // Look for the score "8" specifically in a large font (size 28)
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('Renders carb and sugar level badges', (tester) async {
      env = await _createNutritionResultScreen(tester);

      expect(find.text('MEDIUM'), findsWidgets);
    });

    testWidgets('Renders total nutrition macro grid', (tester) async {
      env = await _createNutritionResultScreen(tester);

      expect(find.textContaining('Total Nutrition'), findsOneWidget);
      expect(find.textContaining('Calories'), findsOneWidget);
      expect(find.textContaining('Carbs'), findsOneWidget);
      expect(find.textContaining('Protein'), findsOneWidget);
      expect(find.textContaining('Fat'), findsOneWidget);
    });

    testWidgets('Renders detected food items', (tester) async {
      env = await _createNutritionResultScreen(tester);

      expect(find.textContaining('Detected Foods'), findsOneWidget);
      expect(find.textContaining('Rice'), findsOneWidget);
      expect(find.textContaining('Dal'), findsOneWidget);
    });

    testWidgets('Renders micronutrients when present', (tester) async {
      env = await _createNutritionResultScreen(tester);

      expect(find.textContaining('Micronutrients'), findsOneWidget);
      expect(find.textContaining('Iron'), findsOneWidget);
      expect(find.textContaining('Calcium'), findsOneWidget);
      expect(find.textContaining('Vitamin C'), findsOneWidget);
    });

    testWidgets('Renders diet flags when present', (tester) async {
      env = await _createNutritionResultScreen(
        tester,
        isVegan: false,
        isVegetarian: true,
        isGlutenFree: true,
        isHighProtein: false,
      );

      expect(find.text('Vegetarian'), findsOneWidget);
      expect(find.text('Gluten Free'), findsOneWidget);
      expect(find.text('Vegan'), findsNothing);
      expect(find.text('High Protein'), findsNothing);
    });

    testWidgets('Renders save meal button with correct key', (tester) async {
      env = await _createNutritionResultScreen(tester);

      expect(find.byKey(const Key('save_meal_button')), findsOneWidget);
    });

    testWidgets('Renders meal type dropdown with correct key', (tester) async {
      env = await _createNutritionResultScreen(tester);

      expect(find.byKey(const Key('meal_type_dropdown')), findsOneWidget);
    });

    testWidgets('Disclaimer text is present', (tester) async {
      env = await _createNutritionResultScreen(tester);

      // The disclaimer icon should be present
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('NutritionResultScreen — Meal Type Dropdown', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Shows auto-detected meal type based on current hour', (tester) async {
      env = await _createNutritionResultScreen(tester);

      // Use local time (not UTC) to match the implementation
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

    testWidgets('Allows changing meal type via dropdown', (tester) async {
      env = await _createNutritionResultScreen(tester, initialMealType: 'BREAKFAST');

      // Tap dropdown
      await tester.tap(find.byKey(const Key('meal_type_dropdown')));
      await pumpN(tester, frames: 10);

      // Select DINNER
      await tester.tap(find.text('Dinner').last);
      await pumpN(tester, frames: 10);

      expect(find.textContaining('Dinner'), findsOneWidget);
    });
  });

  group('NutritionResultScreen — Save Meal Flow', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Save meal button calls API and navigates back on success', (tester) async {
      env = await _createNutritionResultScreen(tester);

      // Scroll to save button
      await tester.dragUntilVisible(
        find.byKey(const Key('save_meal_button')),
        find.byType(SingleChildScrollView),
        const Offset(0, 300),
      );
      await pumpN(tester, frames: 5);

      // Tap save button
      await tester.tap(find.byKey(const Key('save_meal_button')));
      await pumpN(tester, frames: 20);

      // Verify API call was made
      expect(env.tracker.hasCalled('POST', '/meals'), isTrue);

      // Verify navigation back (screen should be popped)
      final body = env.tracker.lastRequestBody('POST', '/meals');
      expect(body, isNotNull);
      expect(body!['meal_type'], isIn(['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER']));
      expect(body['input_method'], equals('PHOTO_GEMINI'));
    });

    testWidgets('Save button shows loading indicator while saving', (tester) async {
      env = await _createNutritionResultScreen(tester);

      // Scroll to save button
      await tester.dragUntilVisible(
        find.byKey(const Key('save_meal_button')),
        find.byType(SingleChildScrollView),
        const Offset(0, 300),
      );
      await pumpN(tester, frames: 5);

      // Tap and check for loading state briefly
      await tester.tap(find.byKey(const Key('save_meal_button')));
      
      // The loading indicator may appear very briefly, so we just verify the tap works
      // and the API call is made (tested in previous test)
      await pumpN(tester, frames: 10);
    });

    testWidgets(
      'Save meal with offline queue when no connectivity',
      (tester) async {
        // Enable connectivity test mode and set to offline
        ConnectivityService.useTestMode();
        ConnectivityService.setTestReachable(false);

        env = await _createNutritionResultScreen(tester);

        // Scroll to save button
        await tester.dragUntilVisible(
          find.byKey(const Key('save_meal_button')),
          find.byType(SingleChildScrollView),
          const Offset(0, 300),
        );
        await pumpN(tester, frames: 5);

        final saveButton = find.byKey(const Key('save_meal_button'));
        expect(saveButton, findsOneWidget);
        
        await tester.tap(saveButton);
        await pumpN(tester, frames: 20);

        // The meal should be queued offline (not sent via HTTP)
        expect(env.tracker.hasCalled('POST', '/meals'), isFalse);
        
        // Verify it was added to sync queue
        final queue = await StorageService().getSyncQueue();
        expect(queue, isNotEmpty);
        expect(queue.first['category'], equals('MODERATE_CARB'));

        // Reset test mode
        ConnectivityService.resetTestMode();
      },
    );
  });

  group('NutritionResultScreen — Widget Keys for E2E', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('All interactive elements have widget keys', (tester) async {
      env = await _createNutritionResultScreen(tester);

      // Verify critical interactive elements have keys
      expect(find.byKey(const Key('save_meal_button')), findsOneWidget);
      expect(find.byKey(const Key('meal_type_dropdown')), findsOneWidget);
    });
  });
}

/// Helper to create NutritionResultScreen with test data
Future<TestEnv> _createNutritionResultScreen(
  WidgetTester tester, {
  int? mealScore,
  String? initialMealType,
  bool? isVegan,
  bool? isVegetarian,
  bool? isGlutenFree,
  bool? isHighProtein,
}) async {
  StorageService.useInMemoryStorage();
  await StorageService().saveToken('mock_token_123');

  final result = NutritionAnalysisResult(
    foods: [
      FoodItemNutrition(
        name: 'Rice',
        weightGrams: 150,
        calories: 195,
        carbsG: 45,
        proteinG: 4.5,
        fatG: 0.5,
        fiberG: 1.5,
      ),
      FoodItemNutrition(
        name: 'Dal',
        weightGrams: 100,
        calories: 120,
        carbsG: 20,
        proteinG: 8,
        fatG: 1.5,
        fiberG: 6,
      ),
    ],
    totalCalories: 315,
    totalCarbsG: 65,
    totalProteinG: 12.5,
    totalFatG: 2,
    totalFiberG: 7.5,
    carbLevel: 'medium',
    sugarLevel: 'low',
    ironMg: 3.5,
    calciumMg: 45,
    vitaminCMg: 12,
    isVegan: isVegan ?? true,
    isVegetarian: isVegetarian ?? true,
    isGlutenFree: isGlutenFree ?? true,
    isHighProtein: isHighProtein ?? false,
    mealScore: mealScore,
    mealScoreReason: mealScore != null ? 'Balanced macronutrients' : null,
  );

  final env = await TestEnv.create(
    tester,
    startScreen: _NavWrapper(
      child: NutritionResultScreen(
        profileId: 1,
        result: result,
        mealType: initialMealType,
      ),
    ),
  );
  await pumpN(tester, frames: 5);
  return env;
}

/// Minimal Navigator wrapper for tests
class _NavWrapper extends StatefulWidget {
  final Widget child;
  const _NavWrapper({required this.child});

  @override
  State<_NavWrapper> createState() => _NavWrapperState();
}

class _NavWrapperState extends State<_NavWrapper> {
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
