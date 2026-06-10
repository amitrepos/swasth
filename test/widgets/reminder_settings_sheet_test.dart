import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/reminder_service.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/widgets/reminder_settings_sheet.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  Size physicalSize = const Size(800, 1200),
}) async {
  tester.view.physicalSize = physicalSize;
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

Finder _dailySwitch() => find.byKey(const Key('daily-reminder-switch'));

Finder _weightSwitch() => find.byKey(const Key('weight-reminder-switch'));

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
    ReminderService().scheduleDailyReminderOverride = null;
    ReminderService().skipNotificationCancelForTest = false;
    StorageService.useRealStorage();
  });

  group('daily reminder', () {
    testWidgets('switch stays off when time picker is cancelled', (
      tester,
    ) async {
      await _openSheet(tester);

      final switchFinder = _dailySwitch();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      expect(await ReminderService().isEnabled(), isFalse);
    });

    testWidgets('switch stays off and shows dialog when permission denied', (
      tester,
    ) async {
      ReminderService().permissionCheckOverride = () async => false;
      reminderTimePickerOverride =
          (context, {required TimeOfDay initialTime, helpText}) async =>
              const TimeOfDay(hour: 8, minute: 0);

      await _openSheet(tester);

      final switchFinder = _dailySwitch();
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(switchFinder))!;
      expect(find.text(l10n.notificationPermissionRequired), findsOneWidget);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      expect(await ReminderService().isEnabled(), isFalse);
    });

    testWidgets('switch enables when time picked and permission granted', (
      tester,
    ) async {
      ReminderService().permissionCheckOverride = () async => true;
      ReminderService().scheduleDailyReminderOverride = (hour, minute) async {};
      reminderTimePickerOverride =
          (context, {required TimeOfDay initialTime, helpText}) async =>
              const TimeOfDay(hour: 8, minute: 0);

      await _openSheet(tester);

      final switchFinder = _dailySwitch();
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
      expect(await ReminderService().isEnabled(), isTrue);
      expect(await ReminderService().getHour(), 8);
      expect(await ReminderService().getMinute(), 0);
    });

    testWidgets('switch off disables reminder and shows snackbar', (
      tester,
    ) async {
      await StorageService().setString('reminder_enabled', 'true');
      await StorageService().setString('reminder_hour', '8');
      await StorageService().setString('reminder_minute', '0');
      ReminderService().skipNotificationCancelForTest = true;

      await _openSheet(tester);

      final switchFinder = _dailySwitch();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      expect(await ReminderService().isEnabled(), isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('weight reminder', () {
    testWidgets('switch stays off when time picker is cancelled', (
      tester,
    ) async {
      await _openSheet(tester);

      final switchFinder = _weightSwitch();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    });

    testWidgets('switch enables when permission granted and time picked', (
      tester,
    ) async {
      ReminderService().permissionCheckOverride = () async => true;
      ReminderService().scheduleWeightReminderOverride =
          (day, hour, minute, {required title, required body}) async {};
      reminderTimePickerOverride =
          (context, {required TimeOfDay initialTime, helpText}) async =>
              const TimeOfDay(hour: 10, minute: 30);

      await _openSheet(tester);

      final switchFinder = _weightSwitch();
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
      expect(await ReminderService().weightReminderEnabled(), isTrue);
    });

    testWidgets('switch stays off and shows dialog when permission denied', (
      tester,
    ) async {
      ReminderService().permissionCheckOverride = () async => false;
      reminderTimePickerOverride =
          (context, {required TimeOfDay initialTime, helpText}) async =>
              const TimeOfDay(hour: 9, minute: 0);

      await _openSheet(tester);

      final switchFinder = _weightSwitch();
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(switchFinder))!;
      expect(find.text(l10n.notificationPermissionRequired), findsOneWidget);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      expect(await ReminderService().weightReminderEnabled(), isFalse);
    });

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

    testWidgets('day picker dismiss keeps weekday unchanged', (tester) async {
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

      await tester.tap(find.byType(ModalBarrier).last);
      await tester.pumpAndSettle();

      expect(scheduledDays, isEmpty);
      expect(await ReminderService().weightReminderDay(), 0);
      expect(find.textContaining('Sunday'), findsWidgets);
    });

    testWidgets('time row updates weight reminder time', (tester) async {
      ReminderService().permissionCheckOverride = () async => true;
      ReminderService().scheduleWeightReminderOverride =
          (day, hour, minute, {required title, required body}) async {};

      await StorageService().setString('weight_reminder_enabled', 'true');
      await StorageService().setString('weight_reminder_day', '0');
      await StorageService().setString('weight_reminder_hour', '9');
      await StorageService().setString('weight_reminder_minute', '0');

      reminderTimePickerOverride =
          (context, {required TimeOfDay initialTime, helpText}) async =>
              const TimeOfDay(hour: 11, minute: 15);

      await _openSheet(tester);

      await tester.tap(find.text('Time').last);
      await tester.pumpAndSettle();

      expect(await ReminderService().weightReminderHour(), 11);
      expect(await ReminderService().weightReminderMinute(), 15);
    });

    testWidgets('time row shows dialog when permission denied', (tester) async {
      await StorageService().setString('weight_reminder_enabled', 'true');
      await StorageService().setString('weight_reminder_day', '0');
      await StorageService().setString('weight_reminder_hour', '9');
      await StorageService().setString('weight_reminder_minute', '0');

      ReminderService().permissionCheckOverride = () async => false;
      reminderTimePickerOverride =
          (context, {required TimeOfDay initialTime, helpText}) async =>
              const TimeOfDay(hour: 10, minute: 0);

      await _openSheet(tester);

      await tester.tap(find.text('Time').last);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(await ReminderService().weightReminderHour(), 9);
      expect(await ReminderService().weightReminderMinute(), 0);
    });

    testWidgets('day picker scrolls on small screens without overflow', (
      tester,
    ) async {
      ReminderService().permissionCheckOverride = () async => true;
      ReminderService().scheduleWeightReminderOverride =
          (day, hour, minute, {required title, required body}) async {};

      await StorageService().setString('weight_reminder_enabled', 'true');
      await StorageService().setString('weight_reminder_day', '0');
      await StorageService().setString('weight_reminder_hour', '9');
      await StorageService().setString('weight_reminder_minute', '0');

      await _openSheet(tester, physicalSize: const Size(400, 640));

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sunday'), findsWidgets);

      await tester.drag(find.byType(Scrollable).last, const Offset(0, -280));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Saturday'), findsOneWidget);
    });

    testWidgets('toggling switch off disables reminder', (tester) async {
      ReminderService().permissionCheckOverride = () async => true;
      ReminderService().scheduleWeightReminderOverride =
          (day, hour, minute, {required title, required body}) async {};
      ReminderService().skipNotificationCancelForTest = true;
      reminderTimePickerOverride =
          (context, {required TimeOfDay initialTime, helpText}) async =>
              const TimeOfDay(hour: 9, minute: 0);

      await _openSheet(tester);

      final switchFinder = _weightSwitch();
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      expect(await ReminderService().weightReminderEnabled(), isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
