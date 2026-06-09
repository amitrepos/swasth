import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/reminder_service.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/widgets/reminder_settings_sheet.dart';

Future<void> _openSheet(WidgetTester tester) async {
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
            onPressed: () =>
                showReminderSettingsSheet(context, isParentMounted: () => true),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    StorageService.useInMemoryStorage();
    reminderTimePickerOverride =
        (context, {required TimeOfDay initialTime, helpText}) async => null;
  });

  tearDown(() {
    reminderTimePickerOverride = null;
    ReminderService().permissionCheckOverride = null;
    ReminderService().scheduleWeightReminderOverride = null;
    StorageService.useRealStorage();
  });

  testWidgets('weight switch stays off when time picker is cancelled', (
    tester,
  ) async {
    await _openSheet(tester);

    final switchFinder = find.byKey(const Key('weight-reminder-switch'));
    expect(switchFinder, findsOneWidget);

    final switchBefore = tester.widget<SwitchListTile>(switchFinder);
    expect(switchBefore.value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final switchAfter = tester.widget<SwitchListTile>(switchFinder);
    expect(switchAfter.value, isFalse);
  });

  testWidgets('weight switch enables when permission granted and time picked', (
    tester,
  ) async {
    ReminderService().permissionCheckOverride = () async => true;
    ReminderService().scheduleWeightReminderOverride =
        (day, hour, minute, {required title, required body}) async {};
    reminderTimePickerOverride =
        (context, {required TimeOfDay initialTime, helpText}) async =>
            const TimeOfDay(hour: 10, minute: 30);

    await _openSheet(tester);

    final switchFinder = find.byKey(const Key('weight-reminder-switch'));
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final switchAfter = tester.widget<SwitchListTile>(switchFinder);
    expect(switchAfter.value, isTrue);
    expect(await ReminderService().weightReminderEnabled(), isTrue);
  });

  testWidgets('weight switch stays off and shows dialog when permission denied', (
    tester,
  ) async {
    ReminderService().permissionCheckOverride = () async => false;
    reminderTimePickerOverride =
        (context, {required TimeOfDay initialTime, helpText}) async =>
            const TimeOfDay(hour: 9, minute: 0);

    await _openSheet(tester);

    final switchFinder = find.byKey(const Key('weight-reminder-switch'));
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(
        'Notification permission is required for reminders. Open your phone Settings and allow notifications for Swasth.',
      ),
      findsOneWidget,
    );

    final switchAfter = tester.widget<SwitchListTile>(switchFinder);
    expect(switchAfter.value, isFalse);
    expect(await ReminderService().weightReminderEnabled(), isFalse);
  });
}
