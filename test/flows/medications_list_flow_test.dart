// E2E: MedicationsScreen table list — load, headers, rows, delete.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/medications_screen.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/region_service.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/theme/app_theme.dart';

import '../helpers/test_app.dart' show pumpN;

const _writeAllowed = RegionInfo(
  countryCode: 'IN',
  writeAllowed: true,
  source: 'ip',
);

List<Map<String, dynamic>> _sampleMeds() {
  final now = DateTime.utc(2026, 5, 20, 8, 0).toIso8601String();
  return [
    {
      'id': 1,
      'profile_id': 1,
      'logged_by': 1,
      'name': 'Metformin',
      'dose': '500 mg',
      'frequency': 'Twice daily',
      'taken_at': now,
      'notes': null,
      'created_at': now,
    },
    {
      'id': 2,
      'profile_id': 1,
      'logged_by': 1,
      'name': 'Amlodipine',
      'dose': '5 mg',
      'frequency': 'Once daily',
      'taken_at': now,
      'notes': 'After breakfast',
      'created_at': now,
    },
  ];
}

class _MedicationsListStub extends http.BaseClient {
  int deleteCount = 0;
  int patchCount = 0;
  final List<Map<String, dynamic>> meds;

  _MedicationsListStub({List<Map<String, dynamic>>? initial})
    : meds = List<Map<String, dynamic>>.from(initial ?? _sampleMeds());

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    if (request.method == 'GET' && url.contains('/api/medications')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(meds))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.method == 'PATCH' && url.contains('/api/medications/')) {
      patchCount += 1;
      final id = int.parse(url.split('/').last);
      final idx = meds.indexWhere((m) => m['id'] == id);
      if (idx == -1) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"detail":"not found"}')),
          404,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request is http.Request) {
        final patch = jsonDecode(request.body) as Map<String, dynamic>;
        final existing = meds[idx];
        for (final e in patch.entries) {
          existing[e.key] = e.value;
        }
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(meds[idx]))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.method == 'DELETE' && url.contains('/api/medications/')) {
      deleteCount += 1;
      final id = int.parse(url.split('/').last);
      meds.removeWhere((m) => m['id'] == id);
      return http.StreamedResponse(Stream.value(utf8.encode('')), 204);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"detail":"not found"}')),
      404,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<void> _bootstrap(WidgetTester tester, http.Client client) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;

  final originalErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed') || msg.contains('overflow')) return;
    originalErrorHandler?.call(details);
  };

  StorageService.useInMemoryStorage();
  await StorageService().saveToken('test-token');
  RegionService.setCacheForTest(_writeAllowed);
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
      home: const MedicationsScreen(profileId: 1),
    ),
  );
  await pumpN(tester, frames: 15);
}

void main() {
  group('MedicationsScreen — table list E2E', () {
    testWidgets('renders table with column headers and medicine rows', (
      tester,
    ) async {
      await _bootstrap(tester, _MedicationsListStub());

      expect(find.byKey(const Key('medications-table')), findsOneWidget);
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Medicine'), findsOneWidget);
      expect(find.text('Dose'), findsOneWidget);
      expect(find.text('Frequency'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.text('500 mg'), findsOneWidget);
      expect(find.text('Twice daily'), findsOneWidget);
      expect(find.text('Amlodipine'), findsOneWidget);
      expect(find.text('After breakfast'), findsOneWidget);
      expect(find.byKey(const Key('medications-add-fab')), findsOneWidget);
    });

    testWidgets('delete removes row after confirmation', (tester) async {
      final stub = _MedicationsListStub();
      await _bootstrap(tester, stub);

      expect(find.text('Metformin'), findsOneWidget);
      expect(find.text('Amlodipine'), findsOneWidget);

      final deleteBtn = find.byKey(const Key('medications-delete-1'));
      await tester.ensureVisible(deleteBtn);
      await pumpN(tester);
      await tester.tap(deleteBtn, warnIfMissed: false);
      await pumpN(tester);
      expect(find.text('Delete medication entry?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await pumpN(tester, frames: 15);

      expect(stub.deleteCount, 1);
      expect(find.text('Metformin'), findsNothing);
      expect(find.text('Amlodipine'), findsOneWidget);
    });

    testWidgets('edit opens prefilled sheet and patches row', (tester) async {
      final stub = _MedicationsListStub();
      await _bootstrap(tester, stub);

      expect(find.text('Metformin'), findsOneWidget);
      expect(find.text('500 mg'), findsOneWidget);

      final editBtn = find.byKey(const Key('medications-edit-1'));
      await tester.ensureVisible(editBtn);
      await pumpN(tester);
      await tester.tap(editBtn, warnIfMissed: false);
      await pumpN(tester, frames: 10);

      // Sheet title
      expect(find.text('Edit medicine'), findsOneWidget);

      // Prefilled fields
      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('medication-name-field')),
      );
      expect(nameField.controller?.text ?? '', 'Metformin');

      final doseField = tester.widget<TextFormField>(
        find.byKey(const Key('medication-dose-field')),
      );
      expect(doseField.controller?.text ?? '', '500 mg');

      // Change dose and save changes
      await tester.enterText(
        find.byKey(const Key('medication-dose-field')),
        '750 mg',
      );
      await tester.tap(find.byKey(const Key('medication-save-btn')));
      await pumpN(tester, frames: 20);

      expect(stub.patchCount, 1);
      expect(find.text('750 mg'), findsOneWidget);
    });

    testWidgets('empty state when no medications returned', (tester) async {
      await _bootstrap(tester, _MedicationsListStub(initial: []));

      expect(find.byKey(const Key('medications-table')), findsNothing);
      expect(find.text('No medicines logged yet'), findsOneWidget);
      expect(find.textContaining('doctor'), findsOneWidget);
    });
  });
}
