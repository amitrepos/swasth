library;

/// Phase 4 widget tests for DoctorTriageScreen — pending requests
/// section + accept attestation dialog.
///
/// Uses per-test MockClient via ApiClient.httpClientOverride +
/// in-memory storage. Never uses pumpAndSettle() because the screen
/// has continuous animations.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/doctor/doctor_triage_screen.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/storage_service.dart';

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

Future<void> pumpN(WidgetTester tester, {int times = 3}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

const _doctorProfile = {
  'user_id': 99,
  'full_name': 'Dr. Test',
  'nmc_number': 'BMCR/123456',
  'specialty': 'General Physician',
  'doctor_code': 'DRTES42',
  'is_verified': true,
  'created_at': '2026-01-01T00:00:00Z',
};

const _pendingRequest = {
  'link_id': 101,
  'profile_id': 7,
  'profile_name': 'Sunita Devi',
  'profile_age': 55,
  'profile_gender': 'Female',
  'consent_type': 'in_person_exam',
  'consent_granted_at': '2026-04-09T10:00:00Z',
  'doctor_code_used': 'DRTES42',
};

void main() {
  setUp(() async {
    StorageService.useInMemoryStorage();
    await StorageService().saveToken('mock_token_123');
  });

  tearDown(() {
    ApiClient.httpClientOverride = null;
    StorageService.useRealStorage();
  });

  testWidgets(
    'pending requests section renders with patient info and action buttons',
    (tester) async {
      ApiClient.httpClientOverride = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/api/doctor/me')) {
          return http.Response(jsonEncode(_doctorProfile), 200);
        }
        if (path.endsWith('/api/doctor/patients')) {
          return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
        }
        if (path.endsWith('/api/doctor/patients/pending')) {
          return http.Response(jsonEncode([_pendingRequest]), 200);
        }
        return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
      });

      await tester.pumpWidget(_wrap(const DoctorTriageScreen()));
      await pumpN(tester, times: 6);

      // Pending card + action buttons render
      expect(find.byKey(const Key('pending_request_7')), findsOneWidget);
      expect(find.text('Sunita Devi'), findsOneWidget);
      expect(find.textContaining('In-person visit'), findsOneWidget);
      expect(find.byKey(const Key('pending_accept_7')), findsOneWidget);
      expect(find.byKey(const Key('pending_decline_7')), findsOneWidget);
    },
  );

  testWidgets('tapping Accept opens the attestation dialog', (tester) async {
    ApiClient.httpClientOverride = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/doctor/me')) {
        return http.Response(jsonEncode(_doctorProfile), 200);
      }
      if (path.endsWith('/api/doctor/patients')) {
        return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
      }
      if (path.endsWith('/api/doctor/patients/pending')) {
        return http.Response(jsonEncode([_pendingRequest]), 200);
      }
      return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
    });

    await tester.pumpWidget(_wrap(const DoctorTriageScreen()));
    await pumpN(tester, times: 6);

    await tester.tap(find.byKey(const Key('pending_accept_7')));
    await pumpN(tester, times: 3);

    // Attestation dialog appeared
    expect(find.byKey(const Key('accept_dialog_condition')), findsOneWidget);
    expect(find.byKey(const Key('accept_dialog_submit')), findsOneWidget);
    expect(find.byKey(const Key('accept_dialog_cancel')), findsOneWidget);
    expect(
      find.textContaining('NMC 2020 Telemedicine Guidelines'),
      findsOneWidget,
    );
  });

  testWidgets('tapping Decline opens a confirmation dialog', (tester) async {
    ApiClient.httpClientOverride = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/doctor/me')) {
        return http.Response(jsonEncode(_doctorProfile), 200);
      }
      if (path.endsWith('/api/doctor/patients')) {
        return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
      }
      if (path.endsWith('/api/doctor/patients/pending')) {
        return http.Response(jsonEncode([_pendingRequest]), 200);
      }
      return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
    });

    await tester.pumpWidget(_wrap(const DoctorTriageScreen()));
    await pumpN(tester, times: 6);

    await tester.tap(find.byKey(const Key('pending_decline_7')));
    await pumpN(tester, times: 3);

    expect(find.byKey(const Key('decline_dialog_confirm')), findsOneWidget);
    expect(find.textContaining('Decline Sunita Devi'), findsOneWidget);
  });
}
