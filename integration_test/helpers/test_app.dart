// Test app bootstrap — creates the full SwasthApp with mocked HTTP.
//
// Usage in tests:
//   final env = await TestEnv.create(tester);
//   // ... interact with app ...
//   env.dispose();

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/login_screen.dart';
import 'package:swasth_app/screens/shell_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/screens/reading_confirmation_screen.dart';
import 'package:swasth_app/screens/quick_select_screen.dart';
import 'package:swasth_app/theme/app_theme.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/main.dart' show routeObserver;

import 'mock_http.dart';

/// Test environment — holds mocked HTTP client and provides app bootstrap.
class TestEnv {
  final ApiCallTracker tracker;

  TestEnv._({required this.tracker});

  /// Create a TestEnv and pump the app starting at [startScreen].
  static Future<TestEnv> create(
    WidgetTester tester, {
    Widget? startScreen,
  }) async {
    final tracker = ApiCallTracker();
    final mockClient = createMockClient(tracker: tracker);

    // Inject mock HTTP client into all services via ApiClient
    ApiClient.httpClientOverride = mockClient;

    final app = ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [routeObserver],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          scaffoldBackgroundColor: AppColors.bgPage,
        ),
        home: startScreen ?? const LoginScreen(),
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    return TestEnv._(tracker: tracker);
  }

  /// Start at LoginScreen (default).
  static Future<TestEnv> createAtLogin(WidgetTester tester) =>
      create(tester, startScreen: const LoginScreen());

  /// Start at SelectProfileScreen (simulates post-login state).
  static Future<TestEnv> createAtProfileSelect(WidgetTester tester) =>
      create(tester, startScreen: const SelectProfileScreen());

  /// Start at ReadingConfirmationScreen for BP manual entry.
  static Future<TestEnv> createAtBpEntry(WidgetTester tester) => create(
    tester,
    startScreen: const ReadingConfirmationScreen(
      ocrResult: null,
      deviceType: 'blood_pressure',
      profileId: 1,
    ),
  );

  /// Start at ReadingConfirmationScreen for glucose manual entry.
  static Future<TestEnv> createAtGlucoseEntry(WidgetTester tester) => create(
    tester,
    startScreen: const ReadingConfirmationScreen(
      ocrResult: null,
      deviceType: 'glucose',
      profileId: 1,
    ),
  );

  /// Start at QuickSelectScreen for meal logging.
  static Future<TestEnv> createAtMealSelect(WidgetTester tester) =>
      create(tester, startScreen: const QuickSelectScreen(profileId: 1));

  void dispose() {
    ApiClient.httpClientOverride = null;
  }
}
