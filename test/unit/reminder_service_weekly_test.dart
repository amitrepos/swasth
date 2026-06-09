import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/services/reminder_service.dart';
import 'package:swasth_app/services/storage_service.dart';

void main() {
  setUp(() => StorageService.useInMemoryStorage());
  tearDown(() => StorageService.useRealStorage());

  test('dartWeekdayFromDay0Sunday maps Sunday to 7', () {
    expect(ReminderService.dartWeekdayFromDay0Sunday(0), DateTime.sunday);
  });

  test('weight reminder prefs read back from storage', () async {
    final svc = ReminderService();
    await StorageService().setString('weight_reminder_enabled', 'true');
    await StorageService().setString('weight_reminder_day', '3');
    expect(await svc.weightReminderEnabled(), isTrue);
    expect(await svc.weightReminderDay(), 3);
  });
}
