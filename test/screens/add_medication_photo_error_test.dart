import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/add_medication_screen.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/theme/app_theme.dart';

import '../helpers/test_app.dart' show pumpN;

class _MultipartFailClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' &&
        request.url.path.endsWith('/api/medications')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"detail":"Photo upload failed"}')),
        422,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  }
}

Future<void> _bootstrap(WidgetTester tester, http.Client client) async {
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
      home: Scaffold(
        body: AddMedicationSheet(
          profileId: 1,
          initialPhoto: PlatformFile(
            name: 'pack.jpg',
            size: 6,
            bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0x01, 0x02, 0x03]),
          ),
        ),
      ),
    ),
  );
  await pumpN(tester, frames: 5);
}

void main() {
  tearDown(() {
    ApiClient.httpClientOverride = null;
    StorageService.useRealStorage();
  });

  testWidgets('photo upload failure re-enables save and shows snackbar', (
    tester,
  ) async {
    await _bootstrap(tester, _MultipartFailClient());

    await tester.enterText(
      find.byKey(const Key('medication-name-field')),
      'Metformin',
    );
    await tester.tap(find.byKey(const Key('medication-save-btn')));
    await pumpN(tester, frames: 15);

    final saveButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('medication-save-btn')),
    );
    expect(saveButton.onPressed, isNotNull);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Photo upload failed'), findsOneWidget);
  });
}
