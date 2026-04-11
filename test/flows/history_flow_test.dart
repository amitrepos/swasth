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
      'History empty state — no readings → empty widget, no snackbar',
      (tester) async {
        env = await TestEnv.createAtHistory(
          tester,
          overrides: {'GET /readings': http.Response('[]', 200)},
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
        },
      );

      // Should not crash with ErrorWidget even when API denies access.
      expect(find.byType(ErrorWidget), findsNothing);
      // Empty state shown (no readings to display).
      expect(find.text('No readings yet'), findsOneWidget);
    });
  });
}
