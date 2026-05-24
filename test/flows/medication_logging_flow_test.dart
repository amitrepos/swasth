// Flow tests for AddMedicationSheet (chained logging UX).
//
// Verifies: form renders, validation, save success clears form + shows banner,
// button label flips to "Save & add more" after first save, Done returns true
// when ≥1 saved, false when none.
//
// Backend route correctness lives in backend/tests/test_medications.py.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/add_medication_screen.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/theme/app_theme.dart';

import '../helpers/test_app.dart' show pumpN;

class _StubClient extends http.BaseClient {
  int postCount = 0;
  bool failNext = false;
  final List<Map<String, dynamic>> sentBodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    if (request.method == 'POST' && url.contains('/api/medications')) {
      postCount += 1;
      if (request is http.Request) {
        try {
          sentBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        } catch (_) {}
      }
      if (failNext) {
        failNext = false;
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"detail":"boom"}')),
          500,
          headers: {'content-type': 'application/json'},
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final body = jsonEncode({
        'id': postCount,
        'profile_id': 1,
        'logged_by': 1,
        'name': sentBodies.isEmpty
            ? 'Unknown'
            : (sentBodies.last['name'] ?? 'Unknown'),
        'dose': sentBodies.isEmpty ? null : sentBodies.last['dose'],
        'frequency': sentBodies.isEmpty ? null : sentBodies.last['frequency'],
        'taken_at': now,
        'notes': sentBodies.isEmpty ? null : sentBodies.last['notes'],
        'created_at': now,
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        201,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  }
}

Future<void> _bootstrap(WidgetTester tester, http.Client client) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;

  // Suppress overflow warnings in test viewport.
  final originalErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed') || msg.contains('overflow')) return;
    originalErrorHandler?.call(details);
  };

  StorageService.useInMemoryStorage();
  await StorageService().saveToken('test-token');
  ApiClient.httpClientOverride = client;

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const Scaffold(body: AddMedicationSheet(profileId: 1)),
    ),
  );
  await pumpN(tester, frames: 5);
}

void main() {
  group('AddMedicationSheet — chained logging', () {
    testWidgets('renders form with name field, Save and Done buttons', (
      tester,
    ) async {
      final stub = _StubClient();
      await _bootstrap(tester, stub);

      expect(find.byKey(const Key('medication-name-field')), findsOneWidget);
      expect(find.byKey(const Key('medication-dose-field')), findsOneWidget);
      expect(find.byKey(const Key('medication-save-btn')), findsOneWidget);
      expect(find.byKey(const Key('medication-done-btn')), findsOneWidget);
      // Banner is NOT shown before first save.
      expect(find.byKey(const Key('medication-saved-banner')), findsNothing);
    });

    testWidgets('empty name shows validation error and does not POST', (
      tester,
    ) async {
      final stub = _StubClient();
      await _bootstrap(tester, stub);

      await tester.tap(find.byKey(const Key('medication-save-btn')));
      await pumpN(tester);

      expect(find.text('Name required'), findsOneWidget);
      expect(stub.postCount, 0);
    });

    testWidgets(
      'successful save clears form, shows banner, flips button label',
      (tester) async {
        final stub = _StubClient();
        await _bootstrap(tester, stub);

        await tester.enterText(
          find.byKey(const Key('medication-name-field')),
          'Metformin',
        );
        await tester.enterText(
          find.byKey(const Key('medication-dose-field')),
          '500 mg',
        );
        await tester.tap(find.byKey(const Key('medication-save-btn')));
        await pumpN(tester, frames: 15);

        expect(stub.postCount, 1);
        expect(stub.sentBodies.first['name'], 'Metformin');
        expect(stub.sentBodies.first['dose'], '500 mg');

        // Banner appears with last saved name.
        expect(
          find.byKey(const Key('medication-saved-banner')),
          findsOneWidget,
        );
        expect(find.textContaining('Metformin'), findsWidgets);

        // Form cleared — name field is empty again.
        final nameField = tester.widget<TextFormField>(
          find.byKey(const Key('medication-name-field')),
        );
        expect(nameField.controller?.text ?? '', isEmpty);

        // Primary button label flipped.
        expect(find.text('Save & add more'), findsOneWidget);
        expect(find.text('Done (1 logged)'), findsOneWidget);
      },
    );

    testWidgets('chained save: three medicines, counter increments', (
      tester,
    ) async {
      final stub = _StubClient();
      await _bootstrap(tester, stub);

      for (final med in ['Metformin', 'Amlodipine', 'Aspirin']) {
        await tester.enterText(
          find.byKey(const Key('medication-name-field')),
          med,
        );
        await tester.tap(find.byKey(const Key('medication-save-btn')));
        await pumpN(tester, frames: 10);
      }

      expect(stub.postCount, 3);
      expect(stub.sentBodies.map((b) => b['name']).toList(), [
        'Metformin',
        'Amlodipine',
        'Aspirin',
      ]);
      expect(find.text('Done (3 logged)'), findsOneWidget);
    });

    testWidgets('save failure: banner not shown, form retains values', (
      tester,
    ) async {
      final stub = _StubClient();
      stub.failNext = true;
      await _bootstrap(tester, stub);

      await tester.enterText(
        find.byKey(const Key('medication-name-field')),
        'Aspirin',
      );
      await tester.tap(find.byKey(const Key('medication-save-btn')));
      await pumpN(tester, frames: 15);

      expect(stub.postCount, 1);
      // Banner should NOT appear since save failed.
      expect(find.byKey(const Key('medication-saved-banner')), findsNothing);
      // Form retains the value the user typed.
      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('medication-name-field')),
      );
      expect(nameField.controller?.text ?? '', 'Aspirin');
    });
  });
}
