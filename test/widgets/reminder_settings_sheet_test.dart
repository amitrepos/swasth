import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/reminder_service.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/widgets/reminder_settings_sheet.dart';

Future<void> _openSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

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
    ReminderService().skipNotificationCancelForTest = false;
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

  testWidgets(
    'weight switch stays off and shows dialog when permission denied',
    (tester) async {
      ReminderService().permissionCheckOverride = () async => false;
      reminderTimePickerOverride =
          (context, {required TimeOfDay initialTime, helpText}) async =>
              const TimeOfDay(hour: 9, minute: 0);

      await _openSheet(tester);

      final switchFinder = find.byKey(const Key('weight-reminder-switch'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(switchFinder))!;
      expect(find.text(l10n.notificationPermissionRequired), findsOneWidget);

      final switchAfter = tester.widget<SwitchListTile>(switchFinder);
      expect(switchAfter.value, isFalse);
      expect(await ReminderService().weightReminderEnabled(), isFalse);
    },
  );

  testWidgets('day picker updates weekday and re-schedules reminder', (
    tester,
  ) async {
    ReminderService().permissionCheckOverride = () async => true;
    final scheduledDays = <int>[];
    ReminderService().scheduleWeightReminderOverride =
        (day, hour, minute, {required title, required body}) async {
          scheduledDays.add(day);
        };

    await StorageService().setString('weight_reminder_enabled', 'true');
    await StorageService().setString('weight_reminder_day', '0');
    await StorageService().setString('weight_reminder_hour', '9');
    await StorageService().setString('weight_reminder_minute', '0');

    await _openSheet(tester);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wednesday'));
    await tester.pumpAndSettle();

    expect(scheduledDays.last, 3);
    expect(await ReminderService().weightReminderDay(), 3);
    expect(find.textContaining('Wednesday'), findsWidgets);
  });

  testWidgets('toggling weight switch off disables reminder', (tester) async {
    ReminderService().permissionCheckOverride = () async => true;
    ReminderService().scheduleWeightReminderOverride =
        (day, hour, minute, {required title, required body}) async {};
    ReminderService().skipNotificationCancelForTest = true;
    reminderTimePickerOverride =
        (context, {required TimeOfDay initialTime, helpText}) async =>
            const TimeOfDay(hour: 9, minute: 0);

    await _openSheet(tester);

    final switchFinder = find.byKey(const Key('weight-reminder-switch'));
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    expect(await ReminderService().weightReminderEnabled(), isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
