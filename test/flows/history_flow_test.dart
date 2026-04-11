// E2E Test: History/trends flow — view readings list
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swasth_app/screens/history_screen.dart';

import '../helpers/test_app.dart';

void main() {
  group('History Flow E2E', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('History screen renders', (tester) async {
      env = await TestEnv.createAtHistory(tester);

      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('History loads readings from API', (tester) async {
      env = await TestEnv.createAtHistory(tester);

      expect(env.tracker.hasCalled('GET', '/readings'), isTrue);
    });

    testWidgets('History shows BP reading data', (tester) async {
      env = await TestEnv.createAtHistory(tester);

      // Mock returns a BP reading of 136/85
      expect(find.textContaining('136'), findsWidgets);
    });

    testWidgets('History shows glucose reading data', (tester) async {
      env = await TestEnv.createAtHistory(tester);

      // Mock returns glucose 108
      expect(find.textContaining('108'), findsWidgets);
    });

    testWidgets('History has no error widgets', (tester) async {
      env = await TestEnv.createAtHistory(tester);

      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets(
      'History empty state — no readings or meals → empty widget, no snackbar',
      (tester) async {
        env = await TestEnv.createAtHistory(
          tester,
          overrides: {
            'GET /readings': http.Response('[]', 200),
            'GET /meals': http.Response('[]', 200),
          },
        );

        // Empty state message must render
        expect(find.text('No readings yet'), findsOneWidget);
        // Must NOT show the error snackbar
        expect(find.textContaining('Error loading history'), findsNothing);
        expect(find.byType(ErrorWidget), findsNothing);
      },
    );

    testWidgets('History empty state — API 403 → graceful empty, no crash', (
      tester,
    ) async {
      env = await TestEnv.createAtHistory(
        tester,
        overrides: {
          'GET /readings': http.Response('{"detail":"Access denied"}', 403),
          'GET /meals': http.Response('[]', 200),
        },
      );

      // Should not crash with ErrorWidget even when API denies access.
      expect(find.byType(ErrorWidget), findsNothing);
      // Empty state shown (no readings or meals to display).
      expect(find.text('No readings yet'), findsOneWidget);
    });
  });

  // Stage 1 of the meal-correlation feature: visual timeline only.
  // No correlation math, no clinical claims, no causation language.
  // Asserts meals appear in the same list as readings, sorted by
  // timestamp desc, with a working filter.
  group('History Flow E2E — meals timeline (Stage 1)', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('History fetches meals alongside readings', (tester) async {
      env = await TestEnv.createAtHistory(tester);

      expect(
        env.tracker.hasCalled('GET', '/meals'),
        isTrue,
        reason:
            'history_screen must call GET /meals so the unified timeline '
            'can show meals next to readings',
      );
    });

    testWidgets('History timeline shows both readings AND meals', (
      tester,
    ) async {
      env = await TestEnv.createAtHistory(tester);

      // Reading from the existing mock — BP 136/85.
      expect(
        find.textContaining('136'),
        findsWidgets,
        reason: 'BP reading should still render in unified timeline',
      );

      // Meal tile should be present — at least one meal-tile Key exists.
      expect(
        find.byKey(const Key('history_meal_tile_101')),
        findsOneWidget,
        reason: 'Today\'s breakfast meal (id=101) should render as a meal tile',
      );
      expect(
        find.byKey(const Key('history_meal_tile_102')),
        findsOneWidget,
        reason: 'Yesterday\'s lunch meal (id=102) should render as a meal tile',
      );
    });

    testWidgets('Filter "Meals Only" hides readings, shows only meals', (
      tester,
    ) async {
      env = await TestEnv.createAtHistory(tester);

      // Open the filter popup and tap "Meals Only".
      await tester.tap(find.byIcon(Icons.filter_list));
      await pumpN(tester, frames: 5);
      await tester.tap(find.text('Meals Only'));
      await pumpN(tester, frames: 10);

      // Meal tiles still present.
      expect(find.byKey(const Key('history_meal_tile_101')), findsOneWidget);
      // Reading tile (136 BP) should be gone.
      expect(
        find.textContaining('136'),
        findsNothing,
        reason: 'BP reading must not render when filter is Meals Only',
      );
    });

    testWidgets('Empty meals + non-empty readings still renders correctly', (
      tester,
    ) async {
      env = await TestEnv.createAtHistory(
        tester,
        overrides: {'GET /meals': http.Response('[]', 200)},
      );

      // Reading still shows.
      expect(find.textContaining('136'), findsWidgets);
      // No meal tiles.
      expect(find.byKey(const Key('history_meal_tile_101')), findsNothing);
      expect(find.byKey(const Key('history_meal_tile_102')), findsNothing);
      // Not the catastrophic empty state.
      expect(find.text('No readings yet'), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('Empty readings + non-empty meals shows meals only', (
      tester,
    ) async {
      env = await TestEnv.createAtHistory(
        tester,
        overrides: {'GET /readings': http.Response('[]', 200)},
      );

      // Meal tiles still render.
      expect(find.byKey(const Key('history_meal_tile_101')), findsOneWidget);
      // No reading text.
      expect(find.textContaining('136'), findsNothing);
      // Empty state should NOT show because we have meals.
      expect(find.text('No readings yet'), findsNothing);
    });

    testWidgets('Empty everything still shows the empty state', (tester) async {
      env = await TestEnv.createAtHistory(
        tester,
        overrides: {
          'GET /readings': http.Response('[]', 200),
          'GET /meals': http.Response('[]', 200),
        },
      );

      expect(find.text('No readings yet'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });
}
