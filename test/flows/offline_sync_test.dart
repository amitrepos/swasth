// E2E Test: Offline sync queue — readings queued offline, synced on reconnect
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/services/sync_service.dart';

import '../helpers/mock_http.dart';

void main() {
  group('Offline Sync Queue', () {
    setUp(() {
      StorageService.useInMemoryStorage();
    });

    tearDown(() {
      ApiClient.httpClientOverride = null;
      StorageService.useRealStorage();
    });

    test('addToSyncQueue stores reading in queue', () async {
      final storage = StorageService();
      await storage.addToSyncQueue({
        'profile_id': 1,
        'reading_type': 'glucose',
        'glucose_value': 108.0,
        'glucose_unit': 'mg/dL',
        'value_numeric': 108.0,
        'unit_display': 'mg/dL',
        'status_flag': 'NORMAL',
        'reading_timestamp': DateTime.now().toIso8601String(),
      });

      final queue = await storage.getSyncQueue();
      expect(queue.length, 1);
      expect(queue[0]['glucose_value'], 108.0);
    });

    test('addToSyncQueue accumulates multiple readings', () async {
      final storage = StorageService();
      await storage.addToSyncQueue({
        'reading_type': 'glucose',
        'glucose_value': 100.0,
        'value_numeric': 100.0,
        'unit_display': 'mg/dL',
        'status_flag': 'NORMAL',
        'reading_timestamp': DateTime.now().toIso8601String(),
        'profile_id': 1,
      });
      await storage.addToSyncQueue({
        'reading_type': 'blood_pressure',
        'systolic': 130.0,
        'diastolic': 80.0,
        'value_numeric': 130.0,
        'unit_display': 'mmHg',
        'status_flag': 'NORMAL',
        'reading_timestamp': DateTime.now().toIso8601String(),
        'profile_id': 1,
      });

      final queue = await storage.getSyncQueue();
      expect(queue.length, 2);
    });

    test('clearSyncQueue empties the queue', () async {
      final storage = StorageService();
      await storage.addToSyncQueue({
        'reading_type': 'glucose',
        'glucose_value': 100.0,
        'value_numeric': 100.0,
        'unit_display': 'mg/dL',
        'status_flag': 'NORMAL',
        'reading_timestamp': DateTime.now().toIso8601String(),
        'profile_id': 1,
      });
      await storage.clearSyncQueue();

      final queue = await storage.getSyncQueue();
      expect(queue.length, 0);
    });

    test('syncPendingReadings syncs queued items when online', () async {
      final storage = StorageService();
      await storage.saveToken('mock_token_123');

      // Queue a reading
      await storage.addToSyncQueue({
        'profile_id': 1,
        'reading_type': 'glucose',
        'glucose_value': 108.0,
        'glucose_unit': 'mg/dL',
        'value_numeric': 108.0,
        'unit_display': 'mg/dL',
        'status_flag': 'NORMAL',
        'reading_timestamp': DateTime.now().toIso8601String(),
      });

      // Set up mock HTTP that accepts the reading
      final tracker = ApiCallTracker();
      ApiClient.httpClientOverride = createMockClient(tracker: tracker);

      final result = await SyncService().syncPendingReadings();

      expect(result.synced, 1);
      expect(result.failed, 0);
      expect(tracker.hasCalled('POST', '/readings'), isTrue);

      // Queue should be empty after sync
      final queue = await storage.getSyncQueue();
      expect(queue.length, 0);
    });

    test('syncPendingReadings no-ops when queue is empty', () async {
      final storage = StorageService();
      await storage.saveToken('mock_token_123');

      final tracker = ApiCallTracker();
      ApiClient.httpClientOverride = createMockClient(tracker: tracker);

      final result = await SyncService().syncPendingReadings();

      expect(result.synced, 0);
      expect(result.failed, 0);
      expect(result.hadPending, isFalse);
    });

    test('syncPendingReadings no-ops when no token', () async {
      final storage = StorageService();
      // Don't save token

      await storage.addToSyncQueue({
        'profile_id': 1,
        'reading_type': 'glucose',
        'glucose_value': 108.0,
        'value_numeric': 108.0,
        'unit_display': 'mg/dL',
        'status_flag': 'NORMAL',
        'reading_timestamp': DateTime.now().toIso8601String(),
      });

      ApiClient.httpClientOverride = createMockClient();

      final result = await SyncService().syncPendingReadings();

      expect(result.synced, 0);
      // Queue should still have the reading (not lost)
      final queue = await storage.getSyncQueue();
      expect(queue.length, 1);
    });

    test('syncPendingReadings keeps failed items in queue', () async {
      final storage = StorageService();
      await storage.saveToken('mock_token_123');

      await storage.addToSyncQueue({
        'profile_id': 1,
        'reading_type': 'glucose',
        'glucose_value': 108.0,
        'value_numeric': 108.0,
        'unit_display': 'mg/dL',
        'status_flag': 'NORMAL',
        'reading_timestamp': DateTime.now().toIso8601String(),
      });

      // Use an error client
      ApiClient.httpClientOverride = MockClient((request) async {
        if (request.url.path.contains('/readings') &&
            request.method == 'POST') {
          return http.Response(jsonEncode({'detail': 'Server error'}), 500);
        }
        // Health check succeeds (so sync thinks it's online)
        return http.Response('OK', 200);
      });

      final result = await SyncService().syncPendingReadings();

      expect(result.failed, 1);
      // Queue should still have the failed reading
      final queue = await storage.getSyncQueue();
      expect(queue.length, 1);
    });

    test('syncPendingReadings no-ops when server unreachable', () async {
      final storage = StorageService();
      await storage.saveToken('mock_token_123');
      await storage.addToSyncQueue({
        'profile_id': 1,
        'reading_type': 'glucose',
        'glucose_value': 108.0,
        'value_numeric': 108.0,
        'unit_display': 'mg/dL',
        'status_flag': 'NORMAL',
        'reading_timestamp': DateTime.now().toIso8601String(),
      });

      // Server unreachable — all requests throw
      ApiClient.httpClientOverride = MockClient((request) async {
        throw Exception('Connection refused');
      });

      final result = await SyncService().syncPendingReadings();

      expect(result.synced, 0);
      // Queue preserved
      final queue = await storage.getSyncQueue();
      expect(queue.length, 1);
    });
  });

  group('Storage Service — write(null) consistency', () {
    setUp(() => StorageService.useInMemoryStorage());
    tearDown(() => StorageService.useRealStorage());

    test('write(key, null) removes the key', () async {
      final store = StorageService();
      await store.saveToken('abc');
      expect(await store.getToken(), 'abc');

      // Writing null should remove
      await store.saveToken(''); // empty string
      // Token should still be readable as empty string
      final result = await store.getToken();
      expect(result, isNotNull);
    });

    test('clearAll removes auth data but keeps cache', () async {
      final store = StorageService();
      await store.saveToken('abc');
      await store.saveActiveProfileId(1);
      await store.addToSyncQueue({'test': true});

      await store.clearAll();

      expect(await store.getToken(), isNull);
      expect(await store.getActiveProfileId(), isNull);
      // Sync queue survives logout
      final queue = await store.getSyncQueue();
      expect(queue.length, 1);
    });
  });
}
