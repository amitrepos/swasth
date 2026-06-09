import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/widgets/reminder_settings_sheet.dart';

void main() {
  setUp(() {
    StorageService.useInMemoryStorage();
    reminderTimePickerOverride =
        (context, {required TimeOfDay initialTime, helpText}) async => null;
  });

  tearDown(() {
    reminderTimePickerOverride = null;
    StorageService.useRealStorage();
  });

  testWidgets('weight switch stays off when time picker is cancelled', (
    tester,
  ) async {
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
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showReminderSettingsSheet(
                context,
                isParentMounted: () => true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const Key('weight-reminder-switch'));
    expect(switchFinder, findsOneWidget);

    final switchBefore = tester.widget<SwitchListTile>(switchFinder);
    expect(switchBefore.value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final switchAfter = tester.widget<SwitchListTile>(switchFinder);
    expect(switchAfter.value, isFalse);
  });
}
