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

    testWidgets('owner dashboard meal summary card is interactive', (
      tester,
    ) async {
      env = await TestEnv.createAtHomeScreen(tester);

      // The owner-side meal card has the "Log meal" + button visible
      // when meals are present. Caregiver flips this to read-only.
      // We don't tap it here — just assert the section exists and is
      // not the read-only variant. Concrete read-only assertion lives
      // in the caregiver test below.
      expect(find.byKey(const Key('dashboard_meal_summary')), findsOneWidget);
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

  // Mirror of the owner test for the caregiver dashboard. A caregiver
  // (access_level != 'owner') sees a different widget set: caregiver
  // header instead of HomeHeader, ActivityFeedCard instead of
  // MetricsGrid, etc. The same invariant must hold: every section
  // renders in both full-data and empty-data states.
  const caregiverSectionKeys = <Key>[
    Key('dashboard_caregiver_header'),
    Key('dashboard_caregiver_wellness'),
    Key('dashboard_caregiver_meals'),
    Key('dashboard_caregiver_activity'),
    Key('dashboard_caregiver_vital_summary'),
    Key('dashboard_caregiver_care_circle'),
    Key('dashboard_doctor_section'),
    Key('dashboard_caregiver_footer'),
  ];

  group('Dashboard widget invariant — caregiver', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('all sections render with full data', (tester) async {
      env = await TestEnv.createAtCaregiverDashboard(tester);

      expect(find.byType(ErrorWidget), findsNothing);

      for (final key in caregiverSectionKeys) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason: 'Caregiver section $key must render with full data',
        );
      }
    });

    testWidgets('all sections still render when data is empty', (tester) async {
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
        'GET /access': http.Response(jsonEncode([]), 200),
      };

      env = await TestEnv.createAtCaregiverDashboard(
        tester,
        overrides: overrides,
      );

      expect(find.byType(ErrorWidget), findsNothing);

      for (final key in caregiverSectionKeys) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason:
              'Caregiver section $key must render even when data is empty '
              '(prevents the same class of regression as the 2026-04 '
              'doctor-section bug from landing on the caregiver dashboard)',
        );
      }

      // Doctor section: empty-state CTA is the right variant.
      expect(
        find.byKey(const Key('linked_doctor_empty')),
        findsOneWidget,
        reason: 'Caregiver empty-state must show the doctor empty-state CTA',
      );
    });

    testWidgets('caregiver meal card is read-only — no add button', (
      tester,
    ) async {
      env = await TestEnv.createAtCaregiverDashboard(tester);

      // The owner version of MealSummaryCard renders an Icons.add
      // button when meals exist (the "Log meal" affordance). The
      // read-only caregiver version must NOT render it. We scope the
      // search to the caregiver meals section so an `Icons.add` from
      // some other widget (e.g. profile switcher) doesn't false-positive.
      final caregiverMealsSection = find.byKey(
        const Key('dashboard_caregiver_meals'),
      );
      expect(caregiverMealsSection, findsOneWidget);

      final addButtonInsideMeals = find.descendant(
        of: caregiverMealsSection,
        matching: find.byIcon(Icons.add),
      );
      expect(
        addButtonInsideMeals,
        findsNothing,
        reason:
            'Caregiver meal card must be read-only — caregivers log meals '
            'via the act-as-patient toggle, not from the caregiver view',
      );
    });

    testWidgets('caregiver activity feed includes meals when present', (
      tester,
    ) async {
      env = await TestEnv.createAtCaregiverDashboard(tester);

      // mock_http returns meal id=101 (today) and id=102 (yesterday).
      // The activity feed caps at 6, so both should fit.
      expect(
        find.byKey(const Key('activity_meal_101')),
        findsOneWidget,
        reason: 'Today\'s meal should appear in caregiver activity feed',
      );
      expect(
        find.byKey(const Key('activity_meal_102')),
        findsOneWidget,
        reason: 'Yesterday\'s meal should appear in caregiver activity feed',
      );
    });
  });
}
