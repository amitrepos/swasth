import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'storage_service.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const _morningId = 1;
  static const _eveningId = 2;
  static const _weightId = 3;
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _weightReminderEnabledKey = 'weight_reminder_enabled';
  static const _weightReminderDayKey = 'weight_reminder_day';
  static const _weightReminderHourKey = 'weight_reminder_hour';
  static const _weightReminderMinuteKey = 'weight_reminder_minute';

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(settings);
  }

  Future<bool> _ensureNotificationPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      if (granted == false) return false;
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted == false) return false;
    }
    return true;
  }

  Future<bool> isEnabled() async =>
      (await StorageService().getString(_reminderEnabledKey)) == 'true';

  Future<int> getHour() async =>
      int.tryParse(await StorageService().getString(_reminderHourKey) ?? '') ??
      8;

  Future<int> getMinute() async =>
      int.tryParse(
        await StorageService().getString(_reminderMinuteKey) ?? '',
      ) ??
      0;

  Future<bool> weightReminderEnabled() async =>
      (await StorageService().getString(_weightReminderEnabledKey)) == 'true';

  Future<int> weightReminderDay() async =>
      int.tryParse(
        await StorageService().getString(_weightReminderDayKey) ?? '',
      ) ??
      0;

  Future<int> weightReminderHour() async =>
      int.tryParse(
        await StorageService().getString(_weightReminderHourKey) ?? '',
      ) ??
      9;

  Future<int> weightReminderMinute() async =>
      int.tryParse(
        await StorageService().getString(_weightReminderMinuteKey) ?? '',
      ) ??
      0;

  Future<bool> _checkNotificationPermission() async {
    if (permissionCheckOverride != null) {
      return permissionCheckOverride!();
    }
    return _ensureNotificationPermission();
  }

  Future<bool> enableReminder(int hour, int minute) async {
    if (!await _checkNotificationPermission()) return false;
    await StorageService().setString(_reminderEnabledKey, 'true');
    await StorageService().setString(_reminderHourKey, hour.toString());
    await StorageService().setString(_reminderMinuteKey, minute.toString());
    await _scheduleMorningReminder(hour, minute);
    await _scheduleEveningReminder();
    return true;
  }

  Future<void> disableReminder() async {
    await StorageService().setString(_reminderEnabledKey, 'false');
    await _notifications.cancel(_morningId);
    await _notifications.cancel(_eveningId);
  }

  @visibleForTesting
  Future<bool> Function()? permissionCheckOverride;

  @visibleForTesting
  bool skipNotificationCancelForTest = false;

  Future<bool> enableWeightReminder(
    int day0Sunday,
    int hour,
    int minute, {
    required String notificationTitle,
    required String notificationBody,
  }) async {
    if (!await _checkNotificationPermission()) return false;
    final day = day0Sunday.clamp(0, 6);
    final clampedHour = hour.clamp(0, 23);
    final clampedMinute = minute.clamp(0, 59);
    await StorageService().setString(_weightReminderEnabledKey, 'true');
    await StorageService().setString(_weightReminderDayKey, day.toString());
    await StorageService().setString(
      _weightReminderHourKey,
      clampedHour.toString(),
    );
    await StorageService().setString(
      _weightReminderMinuteKey,
      clampedMinute.toString(),
    );
    await _scheduleWeightReminder(
      day,
      clampedHour,
      clampedMinute,
      title: notificationTitle,
      body: notificationBody,
    );
    return true;
  }

  Future<void> disableWeightReminder() async {
    await StorageService().setString(_weightReminderEnabledKey, 'false');
    if (!skipNotificationCancelForTest) {
      await _notifications.cancel(_weightId);
    }
  }

  Future<void> _scheduleMorningReminder(int hour, int minute) async {
    await _notifications.zonedSchedule(
      _morningId,
      '🩺 Time to check your health!',
      'Log your glucose or BP reading to keep your streak alive.',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'health_reminders',
          'Health Reminders',
          channelDescription: 'Daily health reading reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleEveningReminder() async {
    await _notifications.zonedSchedule(
      _eveningId,
      '⚠️ Don\'t break your streak!',
      'You haven\'t logged a reading today. Your streak ends at midnight!',
      _nextInstanceOfTime(19, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminders',
          'Streak Reminders',
          channelDescription: 'Evening streak-save reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeightReminder(
    int day0Sunday,
    int hour,
    int minute, {
    required String title,
    required String body,
  }) async {
    await _notifications.zonedSchedule(
      _weightId,
      title,
      body,
      _nextInstanceOfWeekdayTime(day0Sunday, hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weight_reminders',
          'Weight Reminders',
          channelDescription: 'Weekly weight logging reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  @visibleForTesting
  static int dartWeekdayFromDay0Sunday(int day0Sunday) {
    return day0Sunday == 0 ? DateTime.sunday : day0Sunday;
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(
    int day0Sunday,
    int hour,
    int minute,
  ) {
    return nextInstanceOfWeekdayTime(
      day0Sunday,
      hour,
      minute,
      now: tz.TZDateTime.now(tz.local),
    );
  }

  @visibleForTesting
  static tz.TZDateTime nextInstanceOfWeekdayTime(
    int day0Sunday,
    int hour,
    int minute, {
    required tz.TZDateTime now,
  }) {
    final targetWeekday = dartWeekdayFromDay0Sunday(day0Sunday);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    var daysUntil = (targetWeekday - scheduled.weekday) % 7;
    if (daysUntil == 0 && scheduled.isBefore(now)) {
      daysUntil = 7;
    }
    return scheduled.add(Duration(days: daysUntil));
  }
}
