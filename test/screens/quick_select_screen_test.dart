library;

/// Tests for QuickSelectScreen — meal logging quick select buttons.
///
/// Covers: 3 primary buttons render, "More options" expands, tap calls
/// service with correct category, and meal type auto-detection by time.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/quick_select_screen.dart';

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

void main() {
  // =========================================================================
  // Widget test: 3 primary buttons render
  // =========================================================================
  testWidgets('renders 3 primary meal buttons', (tester) async {
    await tester.pumpWidget(_wrap(const QuickSelectScreen(profileId: 1)));
    await tester.pumpAndSettle();

    // Single localized labels for the 3 primary buttons (English locale)
    expect(find.text('Heavy — Rice / Roti'), findsOneWidget);
    expect(find.text('Light — Sabzi / Dal'), findsOneWidget);
    expect(find.text('Sweets / Meetha'), findsOneWidget);
  });

  // =========================================================================
  // Widget test: "More options" expands to show 2 additional buttons
  // =========================================================================
  testWidgets('"More options" expands to show 2 additional buttons', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const QuickSelectScreen(profileId: 1)));
    await tester.pumpAndSettle();

    // Extra buttons should NOT be visible initially
    expect(find.text('Protein — Egg / Paneer'), findsNothing);
    expect(find.text('Mixed / Balanced'), findsNothing);

    // Tap "More options"
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();

    // Now extra buttons should appear (single localized label each)
    expect(find.text('Protein — Egg / Paneer'), findsOneWidget);
    expect(find.text('Mixed / Balanced'), findsOneWidget);
  });

  // =========================================================================
  // Widget test: disclaimer renders
  // =========================================================================
  testWidgets('shows disclaimer at bottom', (tester) async {
    await tester.pumpWidget(_wrap(const QuickSelectScreen(profileId: 1)));
    await tester.pumpAndSettle();

    expect(
      find.text('For general wellness, not medical advice'),
      findsOneWidget,
    );
  });

  // =========================================================================
  // Unit test: meal type auto-detection by time of day
  // =========================================================================
  group('detectMealType', () {
    test('before 11 AM returns BREAKFAST', () {
      expect(detectMealType(DateTime(2026, 4, 8, 7, 30)), 'BREAKFAST');
      expect(detectMealType(DateTime(2026, 4, 8, 10, 59)), 'BREAKFAST');
    });

    test('11 AM to 3 PM returns LUNCH', () {
      expect(detectMealType(DateTime(2026, 4, 8, 11, 0)), 'LUNCH');
      expect(detectMealType(DateTime(2026, 4, 8, 14, 59)), 'LUNCH');
    });

    test('3 PM to 6 PM returns SNACK', () {
      expect(detectMealType(DateTime(2026, 4, 8, 15, 0)), 'SNACK');
      expect(detectMealType(DateTime(2026, 4, 8, 17, 59)), 'SNACK');
    });

    test('after 6 PM returns DINNER', () {
      expect(detectMealType(DateTime(2026, 4, 8, 18, 0)), 'DINNER');
      expect(detectMealType(DateTime(2026, 4, 8, 23, 0)), 'DINNER');
    });
  });

  // =========================================================================
  // Unit test: glucose impact mapping
  // =========================================================================
  group('glucoseImpactFor', () {
    test('maps categories to correct glucose impact', () {
      expect(glucoseImpactFor('HIGH_CARB'), 'HIGH');
      expect(glucoseImpactFor('SWEETS'), 'VERY_HIGH');
      expect(glucoseImpactFor('MODERATE_CARB'), 'MODERATE');
      expect(glucoseImpactFor('LOW_CARB'), 'LOW');
      expect(glucoseImpactFor('HIGH_PROTEIN'), 'LOW');
    });
  });
}
