// Test app bootstrap — creates the full SwasthApp with mocked HTTP.
//
// IMPORTANT: Never use pumpAndSettle() in tests that touch screens with
// AnimationController.repeat() or CircularProgressIndicator — they create
// infinite animations that cause pumpAndSettle to hang for 10 minutes.
// Always use pumpN() or pump(Duration) instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/unified_login_screen.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/screens/reading_confirmation_screen.dart';
import 'package:swasth_app/screens/quick_select_screen.dart';
import 'package:swasth_app/screens/chat_screen.dart';
import 'package:swasth_app/screens/history_screen.dart';
import 'package:swasth_app/screens/home_screen.dart';
import 'package:swasth_app/theme/app_theme.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/main.dart' show routeObserver;
import 'package:http/http.dart' as http;

import 'mock_http.dart';

/// Pump multiple frames — safe replacement for pumpAndSettle().
/// Use this instead of pumpAndSettle to avoid infinite animation hangs.
Future<void> pumpN(
  WidgetTester tester, {
  int frames = 10,
  Duration interval = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(interval);
  }
}

/// Test environment — holds mocked HTTP client and provides app bootstrap.
class TestEnv {
  final ApiCallTracker tracker;
  final void Function(FlutterErrorDetails)? _originalErrorHandler;

  TestEnv._({
    required this.tracker,
    void Function(FlutterErrorDetails)? originalErrorHandler,
  }) : _originalErrorHandler = originalErrorHandler;

  /// Create a TestEnv and pump the app starting at [startScreen].
  static Future<TestEnv> create(
    WidgetTester tester, {
    Widget? startScreen,
    Map<String, http.Response> overrides = const {},
  }) async {
    // Tall phone surface (412x915 logical pixels) — avoids overflow and
    // ensures buttons at bottom of scrollable forms are reachable
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    // Suppress RenderFlex overflow errors (viewport size issue, not a bug)
    final originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('overflowed') || msg.contains('overflow')) return;
      originalErrorHandler?.call(details);
    };

    // Use in-memory storage (FlutterSecureStorage hangs without native plugin)
    StorageService.useInMemoryStorage();

    final tracker = ApiCallTracker();
    final mockClient = createMockClient(tracker: tracker, overrides: overrides);
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
        home: startScreen ?? const UnifiedLoginScreen(),
      ),
    );

    await tester.pumpWidget(app);
    await pumpN(tester, frames: 5); // let initState + first build complete

    return TestEnv._(
      tracker: tracker,
      originalErrorHandler: originalErrorHandler,
    );
  }

  /// Start at LoginScreen (default).
  static Future<TestEnv> createAtLogin(WidgetTester tester) =>
      create(tester, startScreen: const UnifiedLoginScreen());

  /// Start at SelectProfileScreen (simulates post-login state).
  static Future<TestEnv> createAtProfileSelect(WidgetTester tester) async {
    // Switch to in-memory storage FIRST, then seed token BEFORE pumpWidget
    StorageService.useInMemoryStorage();
    await StorageService().saveToken('mock_token_123');
    final env = await create(tester, startScreen: const SelectProfileScreen());
    // Extra pumps for async profile loading from mock API
    await pumpN(tester, frames: 15);
    return env;
  }

  /// Start at ReadingConfirmationScreen for BP manual entry.
  static Future<TestEnv> createAtBpEntry(WidgetTester tester) async {
    StorageService.useInMemoryStorage();
    await StorageService().saveToken('mock_token_123');
    final env = await create(
      tester,
      startScreen: _NavWrapper(
        child: const ReadingConfirmationScreen(
          ocrResult: null,
          deviceType: 'blood_pressure',
          profileId: 1,
        ),
      ),
    );
    await pumpN(tester, frames: 5); // route transition
    return env;
  }

  /// Start at ReadingConfirmationScreen for glucose manual entry.
  static Future<TestEnv> createAtGlucoseEntry(WidgetTester tester) async {
    StorageService.useInMemoryStorage();
    await StorageService().saveToken('mock_token_123');
    final env = await create(
      tester,
      startScreen: _NavWrapper(
        child: const ReadingConfirmationScreen(
          ocrResult: null,
          deviceType: 'glucose',
          profileId: 1,
        ),
      ),
    );
    await pumpN(tester, frames: 5);
    return env;
  }

  /// Start at QuickSelectScreen for meal logging.
  static Future<TestEnv> createAtMealSelect(WidgetTester tester) async {
    StorageService.useInMemoryStorage();
    await StorageService().saveToken('mock_token_123');
    final env = await create(
      tester,
      startScreen: _NavWrapper(child: const QuickSelectScreen(profileId: 1)),
    );
    await pumpN(tester, frames: 5);
    return env;
  }

  /// Start at ChatScreen.
  static Future<TestEnv> createAtChat(WidgetTester tester) async {
    StorageService.useInMemoryStorage();
    await StorageService().saveToken('mock_token_123');
    final env = await create(tester, startScreen: ChatScreen(profileId: 1));
    await pumpN(tester, frames: 10); // load messages + quota
    return env;
  }

  /// Start at HomeScreen — seeds active profile in storage so the
  /// dashboard renders for the test user. Profile id `1` matches the
  /// `My Health` row returned by mock_http for `GET /profiles/{id}`.
  static Future<TestEnv> createAtHomeScreen(
    WidgetTester tester, {
    Map<String, http.Response> overrides = const {},
  }) async {
    StorageService.useInMemoryStorage();
    final storage = StorageService();
    await storage.saveToken('mock_token_123');
    await storage.saveActiveProfileId(1);
    await storage.saveActiveProfileName('My Health');
    await storage.saveActiveProfileAccessLevel('owner');
    final env = await create(
      tester,
      startScreen: const HomeScreen(),
      overrides: overrides,
    );
    // Let async loaders finish: profile, health score, AI insight,
    // linked doctors, meals.
    await pumpN(tester, frames: 25);
    return env;
  }

  /// Start at HomeScreen with caregiver access (`viewer`) on profile 1,
  /// so `_isCaregiverView` evaluates true and the caregiver dashboard
  /// renders instead of the owner dashboard. Caregivers see read-only
  /// meal summary, activity feed (readings + meals), care circle, and
  /// the doctor section — but cannot log new readings or meals from
  /// the caregiver view itself.
  static Future<TestEnv> createAtCaregiverDashboard(
    WidgetTester tester, {
    Map<String, http.Response> overrides = const {},
  }) async {
    StorageService.useInMemoryStorage();
    final storage = StorageService();
    await storage.saveToken('mock_token_123');
    await storage.saveActiveProfileId(1);
    await storage.saveActiveProfileName('Mummy');
    await storage.saveActiveProfileAccessLevel('viewer');
    final env = await create(
      tester,
      startScreen: const HomeScreen(),
      overrides: overrides,
    );
    // Caregiver loaders run sequentially and include the meals fetch.
    await pumpN(tester, frames: 30);
    return env;
  }

  /// Start at HistoryScreen.
  static Future<TestEnv> createAtHistory(
    WidgetTester tester, {
    Map<String, http.Response> overrides = const {},
  }) async {
    StorageService.useInMemoryStorage();
    await StorageService().saveToken('mock_token_123');
    final env = await create(
      tester,
      startScreen: HistoryScreen(profileId: 1),
      overrides: overrides,
    );
    await pumpN(tester, frames: 10); // load readings
    return env;
  }

  void dispose() {
    ApiClient.httpClientOverride = null;
    StorageService.useRealStorage(); // resets to real storage + wipes in-memory
    FlutterError.onError = _originalErrorHandler;
  }
}

/// Wraps a screen so Navigator.pop/popUntil works in tests.
/// Uses zero-duration route to avoid transition animation hangs.
class _NavWrapper extends StatefulWidget {
  final Widget child;
  const _NavWrapper({required this.child});

  @override
  State<_NavWrapper> createState() => _NavWrapperState();
}

class _NavWrapperState extends State<_NavWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        PageRouteBuilder(
          // ignore: unnecessary_underscores
          pageBuilder: (_, __, ___) => widget.child,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Parent')));
  }
}
