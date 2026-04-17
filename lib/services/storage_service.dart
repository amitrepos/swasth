import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract key-value store — production uses FlutterSecureStorage,
/// tests use an in-memory map.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Production implementation backed by FlutterSecureStorage.
class _SecureKeyValueStore implements KeyValueStore {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  // Note: FlutterSecureStorage doesn't support null values, so we delete instead.
  // This matches InMemoryKeyValueStore behavior for consistency.
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// In-memory implementation for tests (no native plugin needed).
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  KeyValueStore _store = _SecureKeyValueStore();

  /// Switch to in-memory storage for tests.
  /// Safe to call multiple times — reuses existing in-memory store.
  @visibleForTesting
  static void useInMemoryStorage() {
    if (_instance._store is! InMemoryKeyValueStore) {
      _instance._store = InMemoryKeyValueStore();
    }
  }

  /// Restore real storage after tests.
  @visibleForTesting
  static void useRealStorage() {
    _instance._store = _SecureKeyValueStore();
  }

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _activeProfileIdKey = 'active_profile_id';
  static const String _activeProfileNameKey = 'active_profile_name';
  static const String _activeProfileAccessLevelKey =
      'active_profile_access_level';
  static const String _languageKey = 'language_code';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';
  static const String _cachedProfilesKey = 'cached_profiles';
  static const String _syncQueueKey = 'sync_queue';
  static const String _lastLoginTimestampKey = 'last_login_timestamp';
  static const String _todayStepsKey = 'today_steps';
  static const String _lastStepsDateKey = 'last_steps_date';
  static const String _stepsGoalKey = 'steps_goal';

  Future<void> saveToken(String token) async {
    await _store.write(_tokenKey, token);
  }

  Future<String?> getToken() async {
    return await _store.read(_tokenKey);
  }

  // Delete authentication token (used when token is expired/invaild)
  Future<void> deleteToken() async {
    await _store.delete(_tokenKey);
  }

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _store.write(_userKey, jsonEncode(userData));
  }

  Future<void> saveActiveProfileId(int id) async {
    await _store.write(_activeProfileIdKey, id.toString());
  }

  Future<int?> getActiveProfileId() async {
    final value = await _store.read(_activeProfileIdKey);
    return value != null ? int.tryParse(value) : null;
  }

  Future<void> saveActiveProfileName(String name) async {
    await _store.write(_activeProfileNameKey, name);
  }

  Future<String?> getActiveProfileName() async {
    return await _store.read(_activeProfileNameKey);
  }

  Future<void> saveActiveProfileAccessLevel(String level) async {
    await _store.write(_activeProfileAccessLevelKey, level);
  }

  Future<String?> getActiveProfileAccessLevel() async {
    return await _store.read(_activeProfileAccessLevelKey);
  }

  Future<void> saveLanguage(String languageCode) async {
    await _store.write(_languageKey, languageCode);
  }

  Future<String?> getLanguage() async {
    return await _store.read(_languageKey);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final jsonString = await _store.read(_userKey);
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  Future<bool> isEmailVerified() async {
    final data = await getUserData();
    return data?['email_verified'] == true;
  }

  Future<void> saveCredentials(String email, String password) async {
    await _store.write(_savedEmailKey, email);
    await _store.write(_savedPasswordKey, password);
  }

  Future<({String email, String password})?> getSavedCredentials() async {
    final email = await _store.read(_savedEmailKey);
    final password = await _store.read(_savedPasswordKey);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  Future<void> clearCredentials() async {
    await _store.delete(_savedEmailKey);
    await _store.delete(_savedPasswordKey);
  }

  // ── Offline cache: profiles ──────────────────────────────────────────────

  Future<void> saveProfiles(List<Map<String, dynamic>> profiles) async {
    await _store.write(_cachedProfilesKey, jsonEncode(profiles));
  }

  Future<List<Map<String, dynamic>>?> getCachedProfiles() async {
    final json = await _store.read(_cachedProfilesKey);
    if (json == null) return null;
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  // ── Offline cache: readings (per profile) ──────────────────────────────

  String _readingsKey(int profileId) => 'cached_readings_$profileId';

  Future<void> saveReadings(
    int profileId,
    List<Map<String, dynamic>> readings,
  ) async {
    await _store.write(_readingsKey(profileId), jsonEncode(readings));
  }

  Future<List<Map<String, dynamic>>?> getCachedReadings(int profileId) async {
    final json = await _store.read(_readingsKey(profileId));
    if (json == null) return null;
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  // ── Offline cache: health score (per profile) ──────────────────────────

  String _healthScoreKey(int profileId) => 'cached_health_score_$profileId';

  Future<void> saveHealthScore(int profileId, Map<String, dynamic> data) async {
    await _store.write(_healthScoreKey(profileId), jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getCachedHealthScore(int profileId) async {
    final json = await _store.read(_healthScoreKey(profileId));
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  // ── Sync queue (readings entered offline, pending upload) ──────────────

  Future<void> addToSyncQueue(Map<String, dynamic> reading) async {
    final queue = await getSyncQueue();
    queue.add(reading);
    await _store.write(_syncQueueKey, jsonEncode(queue));
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final json = await _store.read(_syncQueueKey);
    if (json == null) return [];
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveSyncQueue(List<Map<String, dynamic>> queue) async {
    await _store.write(_syncQueueKey, jsonEncode(queue));
  }

  Future<void> clearSyncQueue() async {
    await _store.delete(_syncQueueKey);
  }

  // ── Last login timestamp (for offline session staleness) ───────────────

  Future<void> saveLastLoginTimestamp() async {
    await _store.write(
      _lastLoginTimestampKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getLastLoginTimestamp() async {
    final value = await _store.read(_lastLoginTimestampKey);
    return value != null ? DateTime.tryParse(value) : null;
  }

  // ── Clear auth data (logout) — keeps sync queue & cache intact ─────────

  Future<void> clearAll() async {
    await _store.delete(_tokenKey);
    await _store.delete(_userKey);
    await _store.delete(_activeProfileIdKey);
    await _store.delete(_activeProfileNameKey);
    await clearCredentials();
  }

  Future<void> clearEverything() async {
    await _store.deleteAll();
  }

  Future<String?> getString(String key) async => _store.read(key);
  Future<void> setString(String key, String value) async =>
      _store.write(key, value);

  // ── Steps tracking ─────────────────────────────────────────────────────

  /// Save today's step count
  Future<void> saveTodaySteps(int steps) async {
    await _store.write(_todayStepsKey, steps.toString());
  }

  /// Get today's step count
  Future<int?> getTodaySteps() async {
    final value = await _store.read(_todayStepsKey);
    return value != null ? int.tryParse(value) : null;
  }

  /// Save the date for the last step count
  Future<void> saveLastStepsDate(DateTime date) async {
    await _store.write(_lastStepsDateKey, date.toIso8601String());
  }

  /// Get the date of the last step count
  Future<DateTime?> getLastStepsDate() async {
    final value = await _store.read(_lastStepsDateKey);
    return value != null ? DateTime.tryParse(value) : null;
  }

  /// Save daily step goal
  Future<void> saveStepsGoal(int goal) async {
    await _store.write(_stepsGoalKey, goal.toString());
  }

  /// Get daily step goal
  Future<int?> getStepsGoal() async {
    final value = await _store.read(_stepsGoalKey);
    return value != null ? int.tryParse(value) : null;
  }
}
