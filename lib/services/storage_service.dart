import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _activeProfileIdKey = 'active_profile_id';
  static const String _activeProfileNameKey = 'active_profile_name';
  static const String _activeProfileAccessLevelKey = 'active_profile_access_level';
  static const String _languageKey = 'language_code';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';
  static const String _cachedProfilesKey = 'cached_profiles';
  static const String _syncQueueKey = 'sync_queue';
  static const String _lastLoginTimestampKey = 'last_login_timestamp';

  // Save authentication token
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Get authentication token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Save user data
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(
      key: _userKey,
      value: jsonEncode(userData),
    );
  }

  // Save active profile ID
  Future<void> saveActiveProfileId(int id) async {
    await _storage.write(key: _activeProfileIdKey, value: id.toString());
  }

  // Get active profile ID
  Future<int?> getActiveProfileId() async {
    final value = await _storage.read(key: _activeProfileIdKey);
    return value != null ? int.tryParse(value) : null;
  }

  // Save active profile name
  Future<void> saveActiveProfileName(String name) async {
    await _storage.write(key: _activeProfileNameKey, value: name);
  }

  // Get active profile name
  Future<String?> getActiveProfileName() async {
    return await _storage.read(key: _activeProfileNameKey);
  }

  // Save active profile access level
  Future<void> saveActiveProfileAccessLevel(String level) async {
    await _storage.write(key: _activeProfileAccessLevelKey, value: level);
  }

  // Get active profile access level
  Future<String?> getActiveProfileAccessLevel() async {
    return await _storage.read(key: _activeProfileAccessLevelKey);
  }

  // Save language preference (survives logout)
  Future<void> saveLanguage(String languageCode) async {
    await _storage.write(key: _languageKey, value: languageCode);
  }

  // Get language preference
  Future<String?> getLanguage() async {
    return await _storage.read(key: _languageKey);
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData() async {
    final jsonString = await _storage.read(key: _userKey);
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  // Save credentials for "Remember me"
  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _savedEmailKey, value: email);
    await _storage.write(key: _savedPasswordKey, value: password);
  }

  // Get saved credentials — returns null if none saved
  Future<({String email, String password})?> getSavedCredentials() async {
    final email = await _storage.read(key: _savedEmailKey);
    final password = await _storage.read(key: _savedPasswordKey);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  // Clear saved credentials (called when user unticks "Remember me" or logs out)
  Future<void> clearCredentials() async {
    await _storage.delete(key: _savedEmailKey);
    await _storage.delete(key: _savedPasswordKey);
  }

  // ── Offline cache: profiles ──────────────────────────────────────────────

  Future<void> saveProfiles(List<Map<String, dynamic>> profiles) async {
    await _storage.write(key: _cachedProfilesKey, value: jsonEncode(profiles));
  }

  Future<List<Map<String, dynamic>>?> getCachedProfiles() async {
    final json = await _storage.read(key: _cachedProfilesKey);
    if (json == null) return null;
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  // ── Offline cache: readings (per profile) ──────────────────────────────

  String _readingsKey(int profileId) => 'cached_readings_$profileId';

  Future<void> saveReadings(int profileId, List<Map<String, dynamic>> readings) async {
    await _storage.write(key: _readingsKey(profileId), value: jsonEncode(readings));
  }

  Future<List<Map<String, dynamic>>?> getCachedReadings(int profileId) async {
    final json = await _storage.read(key: _readingsKey(profileId));
    if (json == null) return null;
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  // ── Offline cache: health score (per profile) ──────────────────────────

  String _healthScoreKey(int profileId) => 'cached_health_score_$profileId';

  Future<void> saveHealthScore(int profileId, Map<String, dynamic> data) async {
    await _storage.write(key: _healthScoreKey(profileId), value: jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getCachedHealthScore(int profileId) async {
    final json = await _storage.read(key: _healthScoreKey(profileId));
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  // ── Sync queue (readings entered offline, pending upload) ──────────────

  Future<void> addToSyncQueue(Map<String, dynamic> reading) async {
    final queue = await getSyncQueue();
    queue.add(reading);
    await _storage.write(key: _syncQueueKey, value: jsonEncode(queue));
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final json = await _storage.read(key: _syncQueueKey);
    if (json == null) return [];
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveSyncQueue(List<Map<String, dynamic>> queue) async {
    await _storage.write(key: _syncQueueKey, value: jsonEncode(queue));
  }

  Future<void> clearSyncQueue() async {
    await _storage.delete(key: _syncQueueKey);
  }

  // ── Last login timestamp (for offline session staleness) ───────────────

  Future<void> saveLastLoginTimestamp() async {
    await _storage.write(
      key: _lastLoginTimestampKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getLastLoginTimestamp() async {
    final value = await _storage.read(key: _lastLoginTimestampKey);
    return value != null ? DateTime.tryParse(value) : null;
  }

  // ── Clear auth data (logout) — keeps sync queue & cache intact ─────────

  Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _activeProfileIdKey);
    await _storage.delete(key: _activeProfileNameKey);
    await clearCredentials();
    // NOTE: cached_profiles, cached_readings_*, sync_queue, and
    // last_login_timestamp are intentionally NOT cleared so offline
    // data and pending uploads survive logout.
  }

  /// Explicit full wipe — clears everything including offline caches.
  Future<void> clearEverything() async {
    await _storage.deleteAll();
  }
}
