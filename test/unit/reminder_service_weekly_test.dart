import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/services/reminder_service.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  setUp(() {
    StorageService.useInMemoryStorage();
    ReminderService().skipNotificationCancelForTest = true;
  });
  tearDown(() {
    ReminderService().permissionCheckOverride = null;
    ReminderService().skipNotificationCancelForTest = false;
    StorageService.useRealStorage();
  });

  test('dartWeekdayFromDay0Sunday maps Sunday to 7', () {
    expect(ReminderService.dartWeekdayFromDay0Sunday(0), DateTime.sunday);
  });

  test('dartWeekdayFromDay0Sunday maps Mon–Sat to same value', () {
    for (var day = 1; day <= 6; day++) {
      expect(ReminderService.dartWeekdayFromDay0Sunday(day), day);
    }
  });

  test('weight reminder prefs read back from storage', () async {
    final svc = ReminderService();
    await StorageService().setString('weight_reminder_enabled', 'true');
    await StorageService().setString('weight_reminder_day', '3');
    expect(await svc.weightReminderEnabled(), isTrue);
    expect(await svc.weightReminderDay(), 3);
  });

  test('weightReminderDay defaults to Sunday when unset', () async {
    final svc = ReminderService();
    expect(await svc.weightReminderDay(), 0);
  });

  test('weightReminderHour and Minute default to 9 and 0', () async {
    final svc = ReminderService();
    expect(await svc.weightReminderHour(), 9);
    expect(await svc.weightReminderMinute(), 0);
  });

  test('weightReminderDay falls back when storage is corrupt', () async {
    final svc = ReminderService();
    await StorageService().setString('weight_reminder_day', 'abc');
    expect(await svc.weightReminderDay(), 0);
  });

  test('disableWeightReminder clears enabled flag', () async {
    final svc = ReminderService();
    await StorageService().setString('weight_reminder_enabled', 'true');
    await svc.disableWeightReminder();
    expect(await svc.weightReminderEnabled(), isFalse);
  });

  test(
    'enableWeightReminder returns false and writes nothing when permission denied',
    () async {
      final svc = ReminderService();
      svc.permissionCheckOverride = () async => false;

      final result = await svc.enableWeightReminder(
        0,
        9,
        0,
        notificationTitle: 'T',
        notificationBody: 'B',
      );

      expect(result, isFalse);
      expect(await svc.weightReminderEnabled(), isFalse);
      expect(await StorageService().getString('weight_reminder_day'), isNull);
    },
  );

  group('nextInstanceOfWeekdayTime', () {
    tz.TZDateTime ist(int y, int m, int d, int h, int min) =>
        tz.TZDateTime(tz.local, y, m, d, h, min);

    test('same weekday, time in future schedules today', () {
      // Wednesday 2026-06-10 10:00 IST → target Wed 14:00
      final now = ist(2026, 6, 10, 10, 0);
      final next = ReminderService.nextInstanceOfWeekdayTime(
        3,
        14,
        0,
        now: now,
      );
      expect(next.year, 2026);
      expect(next.month, 6);
      expect(next.day, 10);
      expect(next.hour, 14);
      expect(next.minute, 0);
    });

    test('same weekday, time already past schedules 7 days ahead', () {
      // Wednesday 2026-06-10 20:00 IST → target Wed 08:00
      final now = ist(2026, 6, 10, 20, 0);
      final next = ReminderService.nextInstanceOfWeekdayTime(3, 8, 0, now: now);
      expect(next.day, 17);
      expect(next.hour, 8);
    });

    test('Sunday target when time already passed schedules next Sunday', () {
      // Sunday 2026-06-07 22:00 IST → target Sun 09:00
      final now = ist(2026, 6, 7, 22, 0);
      final next = ReminderService.nextInstanceOfWeekdayTime(0, 9, 0, now: now);
      expect(next.day, 14);
      expect(next.weekday, DateTime.sunday);
      expect(next.hour, 9);
    });

    test('Monday target from Saturday schedules 2 days ahead', () {
      // Saturday 2026-06-06 12:00 IST → target Mon 09:00
      final now = ist(2026, 6, 6, 12, 0);
      final next = ReminderService.nextInstanceOfWeekdayTime(1, 9, 0, now: now);
      expect(next.day, 8);
      expect(next.weekday, DateTime.monday);
    });
  });
}
