// E2E Test: Dashboard widget invariant — every section must always
// render. This test exists because the doctor section silently
// disappeared in 2026-04 when the guard was tied to a legacy field
// (`profile.doctor_name`) instead of `DoctorPatientLink`. Empty data
// should NEVER drop a section — it should render an empty-state CTA.
//
// RULE: when adding a new dashboard section, add its `Key('dashboard_*')`
// here so this test guards against regressions.
//
// RULE: never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swasth_app/screens/home_screen.dart';

import '../helpers/test_app.dart';

/// The set of section keys the owner dashboard MUST always render.
/// AI insight is intentionally excluded from the "must always render"
/// set because it is gated on `_aiInsightFuture != null`, which only
/// becomes true after a successful health-score load. The "with data"
/// scenario asserts it; the "empty data" scenario does not.
const _ownerSectionKeys = <Key>[
  Key('dashboard_header'),
  Key('dashboard_health_score'),
  Key('dashboard_metrics_grid'),
  Key('dashboard_meal_summary'),
  Key('dashboard_doctor_section'),
  Key('dashboard_device_status'),
  Key('dashboard_vital_summary'),
  Key('dashboard_quick_actions'),
  Key('dashboard_footer'),
];

void main() {
  group('Dashboard widget invariant — owner', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('all sections render with full data', (tester) async {
      env = await TestEnv.createAtHomeScreen(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      for (final key in _ownerSectionKeys) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason: 'Dashboard section $key must render with full data',
        );
      }

      // With full data, AI insight is also expected.
      expect(
        find.byKey(const Key('dashboard_ai_insight')),
        findsOneWidget,
        reason: 'AI insight should render when health score loads',
      );

      // Doctor section should be the populated LinkedDoctorsCard, not
      // the empty state — mock_http returns one active linked doctor.
      expect(
        find.byKey(const Key('linked_doctor_name')),
        findsOneWidget,
        reason: 'Linked doctor name should be visible',
      );
      expect(find.text('Dr. Omisha Sharma'), findsOneWidget);
    });

    testWidgets('all sections still render when data is empty', (tester) async {
      // Override every data endpoint to return empty/null payloads.
      // This simulates a brand-new user who just signed up: no health
      // readings, no linked doctor, no meals, no AI insight cached.
      final overrides = <String, http.Response>{
        'GET /readings': http.Response(jsonEncode([]), 200),
        'GET /health-score': http.Response(
          jsonEncode({
            'score': 0,
            'streak_days': 0,
            'today_bp_status': null,
            'today_glucose_status': null,
            'profile_age': 65,
            'profile_height': null,
            'profile_weight': null,
            'bmi': null,
            'bmi_category': null,
          }),
          200,
        ),
        'GET /meals': http.Response(jsonEncode([]), 200),
        'GET /doctor/link/1': http.Response(jsonEncode([]), 200),
      };

      env = await TestEnv.createAtHomeScreen(tester, overrides: overrides);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);

      // CRITICAL invariant: every section key still resolves, even
      // with no data. A regression that drops a widget here means a
      // user with empty data sees a broken/incomplete dashboard.
      for (final key in _ownerSectionKeys) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason:
              'Dashboard section $key must render even when data is empty '
              '(regression: doctor section silently disappeared when no '
              'doctor was linked, until 2026-04)',
        );
      }

      // Doctor section must show the empty-state CTA, not silently
      // disappear. This is the specific 2026-04 regression we're guarding.
      expect(
        find.byKey(const Key('linked_doctor_empty')),
        findsOneWidget,
        reason: 'Empty-state copy must be visible when no doctor is linked',
      );
      expect(
        find.byKey(const Key('link_doctor_cta')),
        findsOneWidget,
        reason: 'Link-a-doctor CTA must be tappable when section is empty',
      );
    });
  });
}
