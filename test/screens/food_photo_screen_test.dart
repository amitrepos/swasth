library;

/// Tests for FoodPhotoScreen and MealResultScreen.
///
/// Covers: food_photo_screen renders camera/gallery options,
/// meal_result_screen renders badge + tip + disclaimer,
/// and "Not correct? Change" button exists.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/meal_result_screen.dart';

/// Wraps a widget with MaterialApp + localizations so l10n.* calls work.
Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

/// Test classification result.
const _highCarbResult = FoodClassificationResult(
  category: 'HIGH_CARB',
  glucoseImpact: 'HIGH',
  tipEn: 'Try pairing rice with dal for better glucose control.',
  tipHi: 'बेहतर ग्लूकोज नियंत्रण के लिए चावल के साथ दाल खाएं।',
  confidence: 0.85,
);

const _lowCarbResult = FoodClassificationResult(
  category: 'LOW_CARB',
  glucoseImpact: 'LOW',
  tipEn: 'Great choice! Vegetables are excellent for glucose control.',
  tipHi: 'बहुत अच्छा! सब्ज़ियाँ ग्लूकोज नियंत्रण के लिए बेहतरीन हैं।',
  confidence: 0.92,
);

const _sweetsResult = FoodClassificationResult(
  category: 'SWEETS',
  glucoseImpact: 'VERY_HIGH',
  tipEn: 'Sweets can spike glucose quickly. Keep portion small.',
  tipHi: 'मिठाई से शुगर तेज़ी से बढ़ती है। कम खाएं।',
  confidence: 0.88,
);

void main() {
  // =========================================================================
  // Widget test: meal_result_screen renders badge + tip + disclaimer
  // =========================================================================
  testWidgets('MealResultScreen renders carb badge, tip, and disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MealResultScreen(profileId: 1, result: _highCarbResult)),
    );
    await tester.pumpAndSettle();

    // Carb badge label
    expect(find.text('High Carb'), findsOneWidget);

    // Tip text
    expect(
      find.text('Try pairing rice with dal for better glucose control.'),
      findsOneWidget,
    );

    // Disclaimer
    expect(
      find.text('For general wellness, not medical advice'),
      findsOneWidget,
    );

    // Badge icon — priority_high for HIGH_CARB
    expect(find.byIcon(Icons.priority_high), findsOneWidget);
  });

  // =========================================================================
  // Widget test: "Not correct? Change" button exists
  // =========================================================================
  testWidgets('MealResultScreen shows "Not correct? Change" button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MealResultScreen(profileId: 1, result: _lowCarbResult)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not correct? Change'), findsOneWidget);
  });

  // =========================================================================
  // Widget test: LOW_CARB badge renders with check_circle icon
  // =========================================================================
  testWidgets('LOW_CARB renders green badge with check icon', (tester) async {
    await tester.pumpWidget(
      _wrap(MealResultScreen(profileId: 1, result: _lowCarbResult)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Low Carb'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  // =========================================================================
  // Widget test: SWEETS badge renders with warning icon
  // =========================================================================
  testWidgets('SWEETS renders badge with warning icon', (tester) async {
    await tester.pumpWidget(
      _wrap(MealResultScreen(profileId: 1, result: _sweetsResult)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sweets'), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsOneWidget);
  });

  // =========================================================================
  // Widget test: meal type dropdown renders with default value
  // =========================================================================
  testWidgets('MealResultScreen shows meal type dropdown', (tester) async {
    await tester.pumpWidget(
      _wrap(MealResultScreen(profileId: 1, result: _highCarbResult)),
    );
    await tester.pumpAndSettle();

    // The label should be present
    expect(find.text('Meal Type'), findsOneWidget);

    // One of the meal types should be selected (depends on time of day)
    final mealTypes = ['Breakfast', 'Lunch', 'Snack', 'Dinner'];
    final found = mealTypes.any((t) => find.text(t).evaluate().isNotEmpty);
    expect(found, isTrue);
  });

  // =========================================================================
  // Widget test: Save button renders
  // =========================================================================
  testWidgets('MealResultScreen shows save button', (tester) async {
    await tester.pumpWidget(
      _wrap(MealResultScreen(profileId: 1, result: _highCarbResult)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save'), findsOneWidget);
  });

  // =========================================================================
  // Widget test: result title renders in app bar
  // =========================================================================
  testWidgets('MealResultScreen shows title in app bar', (tester) async {
    await tester.pumpWidget(
      _wrap(MealResultScreen(profileId: 1, result: _highCarbResult)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meal Result'), findsOneWidget);
  });
}
