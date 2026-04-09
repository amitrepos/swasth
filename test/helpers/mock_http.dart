// Mock HTTP client for E2E tests.
// Intercepts all HTTP calls and returns realistic responses.
// This lets us test the full Flutter UI without a running backend.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Tracks API calls made during tests for assertions.
class ApiCallTracker {
  final List<http.BaseRequest> calls = [];

  void record(http.BaseRequest request) => calls.add(request);

  bool hasCalled(String method, String pathContains) {
    return calls.any(
      (r) => r.method == method && r.url.toString().contains(pathContains),
    );
  }

  void clear() => calls.clear();
}

/// Creates a MockClient that simulates the Swasth backend.
/// Returns realistic responses for all API endpoints.
MockClient createMockClient({ApiCallTracker? tracker}) {
  return MockClient((request) async {
    tracker?.record(request);

    final path = request.url.path;
    final method = request.method;

    // ── Auth endpoints ──────────────────────────────────────────────

    if (path.endsWith('/register') && method == 'POST') {
      return http.Response(
        jsonEncode({
          'id': 1,
          'email': 'test@swasth.app',
          'full_name': 'Test User',
          'access_token': 'mock_token_123',
        }),
        201,
      );
    }

    if (path.endsWith('/login') && method == 'POST') {
      final body = jsonDecode(request.body);
      if (body['email'] == 'test@swasth.app' &&
          body['password'] == 'Test1234!') {
        return http.Response(
          jsonEncode({
            'access_token': 'mock_token_123',
            'token_type': 'bearer',
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'detail': 'Invalid credentials'}), 401);
    }

    if (path.endsWith('/me') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'id': 1,
          'email': 'test@swasth.app',
          'full_name': 'Test User',
          'is_admin': false,
        }),
        200,
      );
    }

    // ── Profile endpoints ───────────────────────────────────────────

    if (path.endsWith('/profiles') && method == 'GET') {
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'name': 'My Health',
            'relationship': 'myself',
            'age': 65,
            'gender': 'Male',
            'height': 170.0,
            'weight': 75.0,
            'blood_group': 'B+',
            'medical_conditions': ['Diabetes T2', 'Hypertension'],
            'access_level': 'owner',
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-04-01T00:00:00Z',
          },
        ]),
        200,
      );
    }

    if (path.endsWith('/profiles') && method == 'POST') {
      final body = jsonDecode(request.body);
      return http.Response(
        jsonEncode({
          'id': 2,
          'name': body['name'] ?? 'New Profile',
          'relationship': body['relationship'],
          'age': body['age'],
          'gender': body['gender'],
          'access_level': 'owner',
        }),
        201,
      );
    }

    if (path.contains('/invites/pending') && method == 'GET') {
      return http.Response(jsonEncode([]), 200);
    }

    // ── Health score + dashboard data ───────────────────────────────

    if (path.contains('/health-score') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'score': 72,
          'score_label': 'Good',
          'profile_name': 'My Health',
          'profile_age': 65,
          'last_bp_systolic': 136.0,
          'last_bp_diastolic': 85.0,
          'last_bp_status': 'HIGH - STAGE 1',
          'last_glucose_value': 108.0,
          'last_glucose_status': 'NORMAL',
          'today_bp_status': 'HIGH - STAGE 1',
          'today_glucose_status': 'NORMAL',
          'avg_bp_systolic_90d': 132.0,
          'avg_bp_diastolic_90d': 82.0,
          'avg_glucose_90d': 115.0,
          'streak_days': 5,
          'bmi': 25.8,
          'bmi_category': 'Overweight',
          'profile_height': 170.0,
          'profile_weight': 75.0,
          'today_spo2_value': 97.0,
          'today_spo2_status': 'NORMAL',
          'last_spo2_value': 97.0,
          'last_spo2_status': 'NORMAL',
          'avg_spo2_90d': 96.8,
          'spo2_data_days': 10,
          'today_steps_count': 3240,
          'today_steps_goal': 7500,
          'last_steps_count': 3240,
          'avg_steps_90d': 4200.0,
          'steps_data_days': 14,
        }),
        200,
      );
    }

    if (path.contains('/ai-insight') && method == 'GET') {
      return http.Response(
        jsonEncode(
          'Your BP is slightly elevated. Consider reducing salt intake and walking 30 minutes daily.',
        ),
        200,
      );
    }

    // ── Health reading endpoints ────────────────────────────────────

    if (path.endsWith('/readings') && method == 'POST') {
      final body = jsonDecode(request.body);
      return http.Response(
        jsonEncode({
          'id': 100,
          'profile_id': body['profile_id'],
          'reading_type': body['reading_type'],
          'systolic': body['systolic'],
          'diastolic': body['diastolic'],
          'glucose_value': body['glucose_value'],
          'glucose_unit': body['glucose_unit'],
          'bp_unit': body['bp_unit'],
          'spo2_value': body['spo2_value'],
          'spo2_unit': body['spo2_unit'],
          'steps_count': body['steps_count'],
          'steps_goal': body['steps_goal'],
          'value_numeric':
              body['value_numeric'] ??
              body['systolic'] ??
              body['glucose_value'] ??
              0,
          'unit_display': body['unit_display'] ?? 'mg/dL',
          'status_flag': body['status_flag'] ?? 'NORMAL',
          'reading_timestamp':
              body['reading_timestamp'] ?? DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        }),
        201,
      );
    }

    if (path.endsWith('/readings') && method == 'GET') {
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'profile_id': 1,
            'reading_type': 'blood_pressure',
            'systolic': 136.0,
            'diastolic': 85.0,
            'bp_unit': 'mmHg',
            'value_numeric': 136.0,
            'unit_display': 'mmHg',
            'status_flag': 'HIGH - STAGE 1',
            'reading_timestamp': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': 2,
            'profile_id': 1,
            'reading_type': 'glucose',
            'glucose_value': 108.0,
            'glucose_unit': 'mg/dL',
            'value_numeric': 108.0,
            'unit_display': 'mg/dL',
            'status_flag': 'NORMAL',
            'reading_timestamp': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          },
        ]),
        200,
      );
    }

    if (path.contains('/stats/summary') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'total_readings': 10,
          'bp_readings': 5,
          'glucose_readings': 5,
        }),
        200,
      );
    }

    // ── Meal endpoints ──────────────────────────────────────────────

    if (path.endsWith('/meals') && method == 'POST') {
      final body = jsonDecode(request.body);
      return http.Response(
        jsonEncode({
          'id': 50,
          'profile_id': body['profile_id'],
          'category': body['category'],
          'glucose_impact': body['glucose_impact'],
          'meal_type': body['meal_type'],
          'input_method': body['input_method'],
          'timestamp': DateTime.now().toIso8601String(),
          'user_confirmed': true,
        }),
        201,
      );
    }

    if (path.contains('/meals/today') && method == 'GET') {
      return http.Response(jsonEncode([]), 200);
    }

    if (path.endsWith('/meals') && method == 'GET') {
      return http.Response(jsonEncode([]), 200);
    }

    // ── Chat endpoints ──────────────────────────────────────────────

    if (path.contains('/chat/send') && method == 'POST') {
      return http.Response(
        jsonEncode({
          'id': 10,
          'ai_response':
              'Based on your recent readings, your blood pressure is slightly elevated. I recommend reducing sodium intake.',
          'remaining_quota': 4,
          'resets_at': DateTime.now()
              .add(const Duration(hours: 24))
              .toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        }),
        200,
      );
    }

    if (path.contains('/chat/messages') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'messages': [],
          'quota': {
            'remaining': 5,
            'resets_at': DateTime.now()
                .add(const Duration(hours: 24))
                .toIso8601String(),
          },
        }),
        200,
      );
    }

    if (path.contains('/chat/quota') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'remaining': 5,
          'resets_at': DateTime.now()
              .add(const Duration(hours: 24))
              .toIso8601String(),
        }),
        200,
      );
    }

    // ── Trend / weekly summary ──────────────────────────────────────

    if (path.contains('/trend-summary') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'bp_trend': 'stable',
          'glucose_trend': 'improving',
          'summary': 'Your readings are stable over the past week.',
        }),
        200,
      );
    }

    if (path.contains('/weekly-summary') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'summary_text':
              'Weekly Summary: 5 readings logged. BP avg: 132/82. Glucose avg: 115 mg/dL.',
        }),
        200,
      );
    }

    if (path.contains('/family-streaks') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'streaks': [
            {'profile_id': 1, 'name': 'My Health', 'streak_days': 5},
          ],
        }),
        200,
      );
    }

    // ── Profile detail (GET /profiles/{id}) ─────────────────────────

    if (RegExp(r'/profiles/\d+$').hasMatch(path) && method == 'GET') {
      return http.Response(
        jsonEncode({
          'id': 1,
          'name': 'My Health',
          'relationship': 'myself',
          'age': 65,
          'gender': 'Male',
          'height': 170.0,
          'weight': 75.0,
          'blood_group': 'B+',
          'medical_conditions': ['Diabetes T2', 'Hypertension'],
          'access_level': 'owner',
          'doctor_name': null,
          'doctor_whatsapp': null,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-04-01T00:00:00Z',
        }),
        200,
      );
    }

    // ── Connectivity check ──────────────────────────────────────────

    if (path.contains('/health') && method == 'GET') {
      return http.Response('OK', 200);
    }

    // ── Default: 404 ────────────────────────────────────────────────
    return http.Response(
      jsonEncode({'detail': 'Not found: $method $path'}),
      404,
    );
  });
}
