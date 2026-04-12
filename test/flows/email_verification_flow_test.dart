// E2E Test: Email verification flow
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swasth_app/screens/email_verification_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  group('Email Verification — Screen', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('Renders OTP field, verify button, skip, and resend', (
      tester,
    ) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      env = await TestEnv.create(
        tester,
        startScreen: const EmailVerificationScreen(email: 'test@swasth.app'),
      );
      await pumpN(tester, frames: 10);

      expect(find.byKey(const Key('email_verify_otp_field')), findsOneWidget);
      expect(find.byKey(const Key('email_verify_button')), findsOneWidget);
      expect(find.byKey(const Key('email_verify_skip')), findsOneWidget);
      expect(find.byKey(const Key('email_verify_resend')), findsOneWidget);
    });

    testWidgets('Skip button navigates to SelectProfileScreen', (tester) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      env = await TestEnv.create(
        tester,
        startScreen: const EmailVerificationScreen(email: 'test@swasth.app'),
      );
      await pumpN(tester, frames: 10);

      await tester.tap(find.byKey(const Key('email_verify_skip')));
      await pumpN(tester, frames: 20);

      expect(find.byType(SelectProfileScreen), findsOneWidget);
    });

    testWidgets('Successful OTP verification updates stored user data', (
      tester,
    ) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      await StorageService().saveUserData({
        'id': 1,
        'email': 'test@swasth.app',
        'full_name': 'Test User',
        'email_verified': false,
      });

      env = await TestEnv.create(
        tester,
        startScreen: const EmailVerificationScreen(email: 'test@swasth.app'),
      );
      await pumpN(tester, frames: 10);

      // Enter valid OTP
      await tester.enterText(
        find.byKey(const Key('email_verify_otp_field')),
        '123456',
      );
      await pumpN(tester, frames: 3);

      // Tap verify
      await tester.tap(find.byKey(const Key('email_verify_button')));
      await pumpN(tester, frames: 20);

      // Verify user data was updated
      final userData = await StorageService().getUserData();
      expect(userData?['email_verified'], true);
    });
  });

  group('Email Verification — Banner on SelectProfileScreen', () {
    late TestEnv env;
    tearDown(() => env.dispose());

    testWidgets('Banner appears when email_verified=false', (tester) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      await StorageService().saveUserData({
        'id': 1,
        'email': 'test@swasth.app',
        'full_name': 'Test User',
        'is_admin': false,
        'email_verified': false,
      });

      env = await TestEnv.create(
        tester,
        startScreen: const SelectProfileScreen(),
      );
      await pumpN(tester, frames: 20);

      expect(find.byKey(const Key('email_verify_banner')), findsOneWidget);
    });

    testWidgets('Banner does NOT appear when email_verified=true', (
      tester,
    ) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      await StorageService().saveUserData({
        'id': 1,
        'email': 'test@swasth.app',
        'full_name': 'Test User',
        'is_admin': false,
        'email_verified': true,
      });

      // Override /me to return email_verified=true so _loadData picks it up
      env = await TestEnv.create(
        tester,
        startScreen: const SelectProfileScreen(),
        overrides: {
          'GET /me': http.Response(
            jsonEncode({
              'id': 1,
              'email': 'test@swasth.app',
              'full_name': 'Test User',
              'is_admin': false,
              'email_verified': true,
            }),
            200,
          ),
        },
      );
      await pumpN(tester, frames: 20);

      expect(find.byKey(const Key('email_verify_banner')), findsNothing);
    });
  });
}
