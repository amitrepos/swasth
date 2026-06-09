library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/doctor/doctor_patient_detail_screen.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/storage_service.dart';

Future<void> pumpN(WidgetTester tester, {int times = 8}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

const _profileId = 7;
const _takenAt = '2026-05-20T08:00:00Z';

final _medications = [
  {
    'id': 1,
    'profile_id': _profileId,
    'name': 'Metformin',
    'dose': '500 mg',
    'frequency': 'Twice daily',
    'intake_period': 'MORNING',
    'taken_at': _takenAt,
    'notes': null,
    'has_photo': true,
  },
  {
    'id': 2,
    'profile_id': _profileId,
    'name': 'Amlodipine',
    'dose': '5 mg',
    'frequency': null,
    'intake_period': 'EVENING',
    'taken_at': _takenAt,
    'notes': null,
    'has_photo': false,
  },
];

void main() {
  setUp(() async {
    StorageService.useInMemoryStorage();
    await StorageService().saveToken('mock_token_123');
  });

  tearDown(() {
    ApiClient.httpClientOverride = null;
    StorageService.useRealStorage();
  });

  testWidgets('doctor medication row shows date and intake period label', (
    tester,
  ) async {
    ApiClient.httpClientOverride = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/doctor/patients/$_profileId/profile')) {
        return http.Response(
          jsonEncode({'name': 'Sunita Devi', 'age': 55}),
          200,
        );
      }
      if (path.endsWith('/api/doctor/patients/$_profileId/summary')) {
        return http.Response(jsonEncode({'latest_bp': null}), 200);
      }
      if (path.endsWith('/api/doctor/patients/$_profileId/readings')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (path.endsWith('/api/doctor/patients/$_profileId/meals')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (path.endsWith('/api/doctor/patients/$_profileId/medications')) {
        return http.Response(jsonEncode(_medications), 200);
      }
      if (path.endsWith('/api/doctor/patients/$_profileId/notes')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (path.endsWith('/api/medications/1/photo')) {
        return http.Response.bytes(
          const [1, 2, 3],
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      }
      return http.Response('{"detail":"not found"}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DoctorPatientDetailScreen(
          profileId: _profileId,
          profileName: 'Sunita Devi',
        ),
      ),
    );
    await pumpN(tester, times: 12);

    expect(find.byKey(const Key('doctor-medications-section')), findsOneWidget);
    expect(find.byKey(const Key('doctor-medication-thumb-1')), findsOneWidget);
    expect(find.textContaining('Morning'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Evening'), findsAtLeastNWidgets(1));
  });
}
