// E2E tests: "Call your doctor" button — 4-case navigation logic
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.
//
// The call button only renders when health score < 40 (kCautionThreshold).
// Each test overrides /health-score to return score=20 and /doctor/link to
// set up the specific doctor scenario under test.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:swasth_app/screens/link_doctor_screen.dart';

import '../helpers/test_app.dart';

// ── Shared override: low health score (score=20 → urgent → shows call button) ─

http.Response _urgentScore() => http.Response(
      jsonEncode({
        'score': 20,
        'score_label': 'Urgent',
        'profile_name': 'My Health',
        'profile_age': 65,
        'last_bp_systolic': 180.0,
        'last_bp_diastolic': 110.0,
        'last_bp_status': 'HIGH - STAGE 2',
        'last_glucose_value': 280.0,
        'last_glucose_status': 'CRITICAL',
        'today_bp_status': 'HIGH - STAGE 2',
        'today_glucose_status': 'CRITICAL',
        'avg_bp_systolic_90d': 165.0,
        'avg_bp_diastolic_90d': 100.0,
        'avg_glucose_90d': 240.0,
        'streak_days': 0,
        'bmi': 31.0,
        'bmi_category': 'Obese',
        'profile_height': 165.0,
        'profile_weight': 84.0,
        'today_spo2_value': null,
        'today_spo2_status': null,
        'last_spo2_value': null,
        'last_spo2_status': null,
        'avg_spo2_90d': null,
        'spo2_data_days': 0,
        'today_steps_count': null,
        'today_steps_goal': 7500,
        'last_steps_count': null,
        'avg_steps_90d': null,
        'steps_data_days': 0,
      }),
      200,
    );

void main() {
  group('Call Doctor Button — navigation logic', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    // ── Case 1: active linked doctor with phone_number (not whatsapp) ────────
    // Verifies the `?? phone_number` fallback in _handleCallDoctorTap.
    testWidgets(
        'call doctor — active linked doctor with phone_number field calls directly',
        (tester) async {
      env = await TestEnv.createAtHomeScreen(
        tester,
        overrides: {
          'GET /health-score': _urgentScore(),
          'GET /doctor/link/1': http.Response(
            jsonEncode([
              {
                'doctor_name': 'Dr. Ravi Kumar',
                'specialty': 'General Physician',
                'doctor_code': 'DRRAV01',
                'is_verified': true,
                'linked_since': '2026-04-01T10:00:00Z',
                'status': 'active',
                // No whatsapp_number — only phone_number
                'phone_number': '+919811223344',
              },
            ]),
            200,
          ),
        },
      );

      final callBtn = find.text('Call your doctor now');
      await tester.scrollUntilVisible(callBtn, 50);
      await tester.tap(callBtn);
      await pumpN(tester);

      // tel: launch is a platform call — verify routing chose the call
      // path (no snackbar, no navigation to LinkDoctorScreen).
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(LinkDoctorScreen), findsNothing);
    });

    // ── Case 2: active linked doctor with phone ────────────────────────────
    testWidgets(
        'call doctor — active linked doctor with phone calls directly',
        (tester) async {
      env = await TestEnv.createAtHomeScreen(
        tester,
        overrides: {
          'GET /health-score': _urgentScore(),
          'GET /doctor/link/1': http.Response(
            jsonEncode([
              {
                'doctor_name': 'Dr. Meena Gupta',
                'specialty': 'Cardiologist',
                'doctor_code': 'DRMEE01',
                'is_verified': true,
                'linked_since': '2026-04-01T10:00:00Z',
                'status': 'active',
                'whatsapp_number': '+919001112222',
              },
            ]),
            200,
          ),
        },
      );

      final callBtn = find.text('Call your doctor now');
      await tester.scrollUntilVisible(callBtn, 50);
      await tester.tap(callBtn);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(LinkDoctorScreen), findsNothing);
    });

    // ── Case 3: linked doctor exists but no phone ──────────────────────────
    testWidgets(
        'call doctor — linked doctor exists but no phone shows snackbar',
        (tester) async {
      env = await TestEnv.createAtHomeScreen(
        tester,
        overrides: {
          'GET /health-score': _urgentScore(),
          'GET /doctor/link/1': http.Response(
            jsonEncode([
              {
                'doctor_name': 'Dr. No Phone',
                'specialty': 'General Physician',
                'doctor_code': 'DRNOP01',
                'is_verified': true,
                'linked_since': '2026-04-01T10:00:00Z',
                'status': 'active',
                // No whatsapp_number or phone_number fields
              },
            ]),
            200,
          ),
        },
      );

      final callBtn = find.text('Call your doctor now');
      await tester.scrollUntilVisible(callBtn, 50);
      await tester.tap(callBtn);
      await pumpN(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(LinkDoctorScreen), findsNothing);
    });

    // ── Case 4: no doctor linked → navigates to LinkDoctorScreen ──────────
    testWidgets(
        'call doctor — no doctor linked navigates to LinkDoctorScreen',
        (tester) async {
      env = await TestEnv.createAtHomeScreen(
        tester,
        overrides: {
          'GET /health-score': _urgentScore(),
          'GET /doctor/link/1': http.Response(jsonEncode([]), 200),
        },
      );

      final callBtn = find.text('Call your doctor now');
      await tester.scrollUntilVisible(callBtn, 50);
      await tester.tap(callBtn);
      await pumpN(tester, frames: 15);

      expect(find.byType(LinkDoctorScreen), findsOneWidget);
    });
  });
}
