/// Tests for LinkDoctorScreen — patient-facing doctor linking flow.
///
/// Covers: doctor lookup by code (success + 404), card rendering with
/// verification badge, and confirmation dialog before linking. Uses
/// ApiClient.httpClientOverride with a per-test MockClient; never uses
/// pumpAndSettle() because the screen has continuous animations.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/link_doctor_screen.dart';
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

/// Mini pump helper — avoids pumpAndSettle which hangs with continuous
/// animations (CLAUDE.md flow-test rule).
Future<void> pumpN(WidgetTester tester, {int times = 3}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

const _verifiedDoctor = {
  'doctor_name': 'Dr. Rajesh Verma',
  'specialty': 'General Physician',
  'clinic_name': 'Patna Clinic',
  'doctor_code': 'DRRAJ52',
  'is_verified': true,
};

const _unverifiedDoctor = {
  'doctor_name': 'Dr. New Doctor',
  'specialty': 'Cardiologist',
  'clinic_name': null,
  'doctor_code': 'DRNEW01',
  'is_verified': false,
};

const _knownDoctorPatel = {
  'doctor_name': 'Dr. Patel',
  'specialty': 'Cardiologist',
  'clinic_name': 'Patna Heart Clinic',
  'doctor_code': 'DRPAT99',
  'is_verified': true,
  'linked_profile_ids': [2],
};

void main() {
  setUp(() async {
    StorageService.useInMemoryStorage();
    await StorageService().saveToken('mock_token_123');
    await StorageService().saveActiveProfileId(1);
  });

  tearDown(() {
    ApiClient.httpClientOverride = null;
    StorageService.useRealStorage();
  });

  testWidgets('shows error text when doctor lookup returns 404', (
    tester,
  ) async {
    ApiClient.httpClientOverride = MockClient((request) async {
      if (request.url.path.contains('/api/doctor/lookup/')) {
        return http.Response(
          jsonEncode({'detail': 'Doctor code not found'}),
          404,
        );
      }
      return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
    });

    await tester.pumpWidget(_wrap(const LinkDoctorScreen()));
    await pumpN(tester);

    // Enter a code and tap Find Doctor
    await tester.enterText(
      find.byKey(const Key('link_doctor_code')),
      'BADCODE',
    );
    await tester.tap(find.byKey(const Key('link_doctor_lookup_button')));
    await pumpN(tester, times: 5);

    // Error message from linkDoctorLookupFailed should appear
    expect(find.text('Doctor not found. Check the code.'), findsOneWidget);
    // And the doctor card should NOT be rendered
    expect(find.byKey(const Key('link_doctor_card')), findsNothing);
  });

  testWidgets('shows verified doctor card after successful lookup', (
    tester,
  ) async {
    ApiClient.httpClientOverride = MockClient((request) async {
      if (request.url.path.contains('/api/doctor/lookup/')) {
        return http.Response(jsonEncode(_verifiedDoctor), 200);
      }
      return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
    });

    await tester.pumpWidget(_wrap(const LinkDoctorScreen()));
    await pumpN(tester);

    await tester.enterText(
      find.byKey(const Key('link_doctor_code')),
      'DRRAJ52',
    );
    await tester.tap(find.byKey(const Key('link_doctor_lookup_button')));
    await pumpN(tester, times: 5);

    // Doctor card + "Verified doctor" badge should render
    expect(find.byKey(const Key('link_doctor_card')), findsOneWidget);
    expect(find.text('Dr. Rajesh Verma'), findsOneWidget);
    expect(find.text('General Physician'), findsOneWidget);
    expect(find.text('Verified doctor'), findsOneWidget);
    // Confirm button appears once the card is visible
    expect(find.byKey(const Key('link_doctor_confirm_button')), findsOneWidget);
  });

  testWidgets('shows Verification pending badge for unverified doctor', (
    tester,
  ) async {
    ApiClient.httpClientOverride = MockClient((request) async {
      if (request.url.path.contains('/api/doctor/lookup/')) {
        return http.Response(jsonEncode(_unverifiedDoctor), 200);
      }
      return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
    });

    await tester.pumpWidget(_wrap(const LinkDoctorScreen()));
    await pumpN(tester);

    await tester.enterText(
      find.byKey(const Key('link_doctor_code')),
      'DRNEW01',
    );
    await tester.tap(find.byKey(const Key('link_doctor_lookup_button')));
    await pumpN(tester, times: 5);

    expect(find.byKey(const Key('link_doctor_card')), findsOneWidget);
    expect(find.text('Dr. New Doctor'), findsOneWidget);
    expect(find.text('Verification pending'), findsOneWidget);
  });

  testWidgets('shows confirmation dialog before linking to a verified doctor', (
    tester,
  ) async {
    var linkCalled = false;
    ApiClient.httpClientOverride = MockClient((request) async {
      if (request.url.path.contains('/api/doctor/lookup/')) {
        return http.Response(jsonEncode(_verifiedDoctor), 200);
      }
      if (request.url.path.contains('/api/doctor/link/')) {
        linkCalled = true;
        return http.Response(
          jsonEncode({
            'id': 1,
            'doctor_name': 'Dr. Rajesh Verma',
            'doctor_code': 'DRRAJ52',
            'consent_type': 'in_person_exam',
            'is_active': true,
            'created_at': '2026-04-10T12:00:00Z',
          }),
          201,
        );
      }
      return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
    });

    await tester.pumpWidget(_wrap(const LinkDoctorScreen()));
    await pumpN(tester);

    await tester.enterText(
      find.byKey(const Key('link_doctor_code')),
      'DRRAJ52',
    );
    await tester.tap(find.byKey(const Key('link_doctor_lookup_button')));
    await pumpN(tester, times: 5);

    // Tap Share my readings — should open the confirmation dialog,
    // NOT fire the link POST yet. The button is below the fold once
    // the doctor card + consent tiles + disclaimers render, so scroll
    // it into view first.
    await tester.ensureVisible(
      find.byKey(const Key('link_doctor_confirm_button')),
    );
    await pumpN(tester);
    await tester.tap(find.byKey(const Key('link_doctor_confirm_button')));
    await pumpN(tester, times: 3);

    expect(find.text('Share your readings?'), findsOneWidget);
    expect(
      find.byKey(const Key('link_doctor_confirm_dialog_share')),
      findsOneWidget,
    );
    expect(linkCalled, isFalse, reason: 'POST should wait for dialog confirm');

    // Tap the Yes, share button — now the POST should fire.
    await tester.tap(find.byKey(const Key('link_doctor_confirm_dialog_share')));
    await pumpN(tester, times: 5);

    expect(linkCalled, isTrue);
  });

  // ---------------------------------------------------------------------
  // Picker tests
  // ---------------------------------------------------------------------

  testWidgets(
    'shows known-doctors picker when /known-doctors returns candidates',
    (tester) async {
      ApiClient.httpClientOverride = MockClient((request) async {
        if (request.url.path.contains('/api/doctor/known-doctors')) {
          return http.Response(jsonEncode([_knownDoctorPatel]), 200);
        }
        if (request.url.path.contains('/api/doctor/link/')) {
          return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
        }
        return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
      });

      await tester.pumpWidget(_wrap(const LinkDoctorScreen()));
      await pumpN(tester, times: 5);

      // Picker card renders
      expect(find.text('Dr. Patel'), findsOneWidget);
      expect(find.text('Patna Heart Clinic'), findsOneWidget);
      // Code field is NOT shown by default when the picker has candidates
      expect(find.byKey(const Key('link_doctor_code')), findsNothing);
      // "Enter a new code" fallback button is visible
      expect(
        find.byKey(const Key('link_doctor_expand_code_button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping a picker card selects the doctor and shows consent flow',
    (tester) async {
      ApiClient.httpClientOverride = MockClient((request) async {
        if (request.url.path.contains('/api/doctor/known-doctors')) {
          return http.Response(jsonEncode([_knownDoctorPatel]), 200);
        }
        if (request.url.path.contains('/api/doctor/link/')) {
          return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
        }
        return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
      });

      await tester.pumpWidget(_wrap(const LinkDoctorScreen()));
      await pumpN(tester, times: 5);

      // No preview card yet
      expect(find.byKey(const Key('link_doctor_card')), findsNothing);

      // Tap Dr. Patel in the picker
      await tester.tap(find.byKey(const Key('link_doctor_picker_DRPAT99')));
      await pumpN(tester, times: 3);

      // Preview card + consent radios + confirm button are shown
      expect(find.byKey(const Key('link_doctor_card')), findsOneWidget);
      expect(find.text('Verified doctor'), findsOneWidget);
      expect(
        find.byKey(const Key('link_doctor_confirm_button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'already-linked picker card shows snackbar and does not open consent',
    (tester) async {
      ApiClient.httpClientOverride = MockClient((request) async {
        if (request.url.path.contains('/api/doctor/known-doctors')) {
          return http.Response(jsonEncode([_knownDoctorPatel]), 200);
        }
        if (request.url.path.contains('/api/doctor/link/')) {
          // This profile already links Dr. Patel, so the picker card
          // for them should render as "already sharing" and be inert.
          return http.Response(
            jsonEncode([
              {
                'doctor_name': 'Dr. Patel',
                'doctor_code': 'DRPAT99',
                'specialty': 'Cardiologist',
                'is_verified': true,
                'linked_since': '2026-04-01T10:00:00Z',
              },
            ]),
            200,
          );
        }
        return http.Response(jsonEncode({'detail': 'unexpected'}), 500);
      });

      await tester.pumpWidget(_wrap(const LinkDoctorScreen()));
      await pumpN(tester, times: 5);

      // The "Already sharing" badge appears on the card
      expect(find.text('Already sharing'), findsOneWidget);

      // Tap the disabled card — shouldn't select anything
      await tester.tap(
        find.byKey(const Key('link_doctor_picker_DRPAT99')),
        warnIfMissed: false,
      );
      await pumpN(tester, times: 3);

      // Preview card did NOT appear (no selection)
      expect(find.byKey(const Key('link_doctor_card')), findsNothing);
    },
  );
}
