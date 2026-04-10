/// Tests for MyLinkedDoctorsScreen — patient-facing linked-doctors list.
///
/// Covers: empty state, list with linked doctors, revoke confirmation
/// dialog + DELETE fires only after Stop sharing tap. Uses per-test
/// MockClient via ApiClient.httpClientOverride + in-memory storage.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/my_linked_doctors_screen.dart';
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

const _linkedDoctors = [
  {
    'doctor_name': 'Dr. Rajesh Verma',
    'specialty': 'General Physician',
    'doctor_code': 'DRRAJ52',
    'is_verified': true,
    'linked_since': '2026-04-08T10:00:00Z',
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

  testWidgets('renders empty state when no doctors are linked', (tester) async {
    ApiClient.httpClientOverride = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.contains('/api/doctor/link/')) {
        return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
      }
      return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
    });

    await tester.pumpWidget(_wrap(const MyLinkedDoctorsScreen(profileId: 1)));
    await pumpN(tester, times: 5);

    expect(
      find.text('No doctor is currently linked to this profile.'),
      findsOneWidget,
    );
  });

  testWidgets('renders list of linked doctors', (tester) async {
    ApiClient.httpClientOverride = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.contains('/api/doctor/link/')) {
        return http.Response(jsonEncode(_linkedDoctors), 200);
      }
      return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
    });

    await tester.pumpWidget(_wrap(const MyLinkedDoctorsScreen(profileId: 1)));
    await pumpN(tester, times: 5);

    expect(find.text('Dr. Rajesh Verma'), findsOneWidget);
    expect(find.text('General Physician'), findsOneWidget);
    expect(find.byKey(const Key('revoke_button_DRRAJ52')), findsOneWidget);
  });

  testWidgets(
    'opens confirmation dialog and calls DELETE only after Stop sharing',
    (tester) async {
      var deleteCalled = false;
      ApiClient.httpClientOverride = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.contains('/api/doctor/link/')) {
          return http.Response(jsonEncode(_linkedDoctors), 200);
        }
        if (request.method == 'DELETE' &&
            request.url.path.contains('/api/doctor/link/')) {
          deleteCalled = true;
          return http.Response(
            jsonEncode({'detail': 'Doctor access revoked'}),
            200,
          );
        }
        return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
      });

      await tester.pumpWidget(_wrap(const MyLinkedDoctorsScreen(profileId: 1)));
      await pumpN(tester, times: 5);

      await tester.ensureVisible(
        find.byKey(const Key('revoke_button_DRRAJ52')),
      );
      await pumpN(tester);
      await tester.tap(find.byKey(const Key('revoke_button_DRRAJ52')));
      await pumpN(tester, times: 3);

      expect(find.byKey(const Key('revoke_dialog_confirm')), findsOneWidget);
      expect(
        deleteCalled,
        isFalse,
        reason: 'DELETE must wait for dialog confirmation',
      );

      await tester.tap(find.byKey(const Key('revoke_dialog_confirm')));
      await pumpN(tester, times: 5);

      expect(deleteCalled, isTrue);
    },
  );
}
