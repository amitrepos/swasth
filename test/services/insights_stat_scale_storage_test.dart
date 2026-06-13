import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/services/storage_service.dart';

void main() {
  setUp(() => StorageService.useInMemoryStorage());
  tearDown(() => StorageService.useRealStorage());

  test('getInsightsStatScale round-trips saved value', () async {
    final svc = StorageService();
    await svc.saveInsightsStatScale(1.35);
    expect(await svc.getInsightsStatScale(), 1.35);
  });

  test('getInsightsStatScale returns 1.0 on corrupt value', () async {
    final svc = StorageService();
    await svc.setString('insights_stat_scale', 'corrupt');
    expect(await svc.getInsightsStatScale(), 1.0);
  });

  test('getInsightsStatScale returns 1.0 when unset', () async {
    expect(await StorageService().getInsightsStatScale(), 1.0);
  });
}
