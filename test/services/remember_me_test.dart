// Test: Remember Me functionality
// This test verifies that credentials save/retrieve logic works correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/services/storage_service.dart';

void main() {
  group('Remember Me - Credentials Storage', () {
    setUp(() {
      // Use in-memory storage for testing (doesn't need Flutter binding)
      StorageService.useInMemoryStorage();
    });

    tearDown(() {
      StorageService.useRealStorage();
    });

    test('Should save and retrieve credentials', () async {
      final storage = StorageService();
      
      // Save credentials
      await storage.saveCredentials('test@example.com', 'password123');
      
      // Retrieve credentials
      final creds = await storage.getSavedCredentials();
      
      expect(creds, isNotNull);
      expect(creds!.email, equals('test@example.com'));
      expect(creds.password, equals('password123'));
    });

    test('Should return null when no credentials are saved', () async {
      final storage = StorageService();
      
      final creds = await storage.getSavedCredentials();
      
      expect(creds, isNull);
    });

    test('Should clear credentials', () async {
      final storage = StorageService();
      
      // Save credentials
      await storage.saveCredentials('test@example.com', 'password123');
      
      // Verify they are saved
      final credsBefore = await storage.getSavedCredentials();
      expect(credsBefore, isNotNull);
      
      // Clear credentials
      await storage.clearCredentials();
      
      // Verify they are cleared
      final credsAfter = await storage.getSavedCredentials();
      expect(credsAfter, isNull);
    });

    test('Should overwrite existing credentials', () async {
      final storage = StorageService();
      
      // Save initial credentials
      await storage.saveCredentials('old@example.com', 'oldpassword');
      
      // Overwrite with new credentials
      await storage.saveCredentials('new@example.com', 'newpassword');
      
      // Verify new credentials are stored
      final creds = await storage.getSavedCredentials();
      expect(creds, isNotNull);
      expect(creds!.email, equals('new@example.com'));
      expect(creds.password, equals('newpassword'));
    });

    test('Should persist credentials after clearAll (logout)', () async {
      final storage = StorageService();
      
      // Save credentials with remember me
      await storage.saveCredentials('test@example.com', 'password123');
      
      // Save other auth data
      await storage.saveToken('some_token');
      
      // Verify credentials are saved
      final credsBefore = await storage.getSavedCredentials();
      expect(credsBefore, isNotNull);
      
      // Simulate logout (clearAll)
      await storage.clearAll();
      
      // Token should be cleared
      expect(await storage.getToken(), isNull);
      
      // BUT credentials should still exist (remember me persists)
      final credsAfter = await storage.getSavedCredentials();
      expect(credsAfter, isNotNull);
      expect(credsAfter!.email, equals('test@example.com'));
      expect(credsAfter.password, equals('password123'));
    });
  });
}
