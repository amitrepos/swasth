import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'storage_service.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const _morningId = 1;
  static const _eveningId = 2;
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);
  }

  Future<bool> isEnabled() async {
    final val = await StorageService().getString(_reminderEnabledKey);
    return val == 'true';
  }

  Future<int> getHour() async {
    final val = await StorageService().getString(_reminderHourKey);
    return int.tryParse(val ?? '') ?? 8; // default 8 AM
  }

  Future<int> getMinute() async {
    final val = await StorageService().getString(_reminderMinuteKey);
    return int.tryParse(val ?? '') ?? 0;
  }

  Future<void> enableReminder(int hour, int minute) async {
    await StorageService().setString(_reminderEnabledKey, 'true');
    await StorageService().setString(_reminderHourKey, hour.toString());
    await StorageService().setString(_reminderMinuteKey, minute.toString());
    await _scheduleMorningReminder(hour, minute);
    await _scheduleEveningReminder();
  }

  Future<void> disableReminder() async {
    await StorageService().setString(_reminderEnabledKey, 'false');
    await _notifications.cancel(_morningId);
    await _notifications.cancel(_eveningId);
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleEveningReminder() async {
    await _notifications.zonedSchedule(
      _eveningId,
      '⚠️ Don\'t break your streak!',
      'You haven\'t logged a reading today. Your streak ends at midnight!',
      _nextInstanceOfTime(19, 0), // 7 PM
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
