import 'connectivity_service.dart';
import 'storage_service.dart';
import 'health_reading_service.dart';
import 'api_service.dart';

class SyncResult {
  final int synced;
  final int failed;
  bool get hadPending => synced + failed > 0;

  SyncResult({required this.synced, required this.failed});
}

class SyncService {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  bool _isSyncing = false;

  /// Flush the offline sync queue. Safe to call frequently — no-ops when
  /// already syncing, offline, or queue is empty.
  Future<SyncResult> syncPendingReadings() async {
    if (_isSyncing) return SyncResult(synced: 0, failed: 0);
    _isSyncing = true;

    try {
      final reachable = await ConnectivityService().isServerReachable();
      if (!reachable) return SyncResult(synced: 0, failed: 0);

      final storage = StorageService();
      var token = await storage.getToken();

      // Token may be expired — try re-login with saved credentials
      if (token == null) {
        final creds = await storage.getSavedCredentials();
        if (creds == null) return SyncResult(synced: 0, failed: 0);
        try {
          final resp = await ApiService().login(creds.email, creds.password);
          token = resp['access_token'] as String?;
          if (token != null) await storage.saveToken(token);
        } catch (_) {
          return SyncResult(synced: 0, failed: 0);
        }
      }
      if (token == null) return SyncResult(synced: 0, failed: 0);

      final queue = await storage.getSyncQueue();
      if (queue.isEmpty) return SyncResult(synced: 0, failed: 0);

      final readingService = HealthReadingService();
      int synced = 0;
      final remaining = <Map<String, dynamic>>[];

      for (final json in queue) {
        try {
          final reading = HealthReading.fromJson({
            ...json,
            'id': json['id'] ?? 0,
            'created_at': json['created_at'] ?? DateTime.now().toIso8601String(),
          });
          await readingService.saveReading(reading, token);
          synced++;
        } catch (_) {
          remaining.add(json);
        }
      }

      await storage.saveSyncQueue(remaining);
      return SyncResult(synced: synced, failed: remaining.length);
    } finally {
      _isSyncing = false;
    }
  }
}
