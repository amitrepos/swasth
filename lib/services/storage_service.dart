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
  static const String _languageKey = 'language_code';
  static const String _savedEmailKey = 'saved_email';
  static const String _savedPasswordKey = 'saved_password';

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

  // Clear all stored data (logout)
  Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _activeProfileIdKey);
    await _storage.delete(key: _activeProfileNameKey);
    await clearCredentials();
  }
}
