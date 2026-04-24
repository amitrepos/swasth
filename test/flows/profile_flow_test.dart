// E2E Test: Profile management flow
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/screens/create_profile_screen.dart';
import 'package:swasth_app/services/storage_service.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('Profile Flow E2E', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Profile selection shows owned profiles', (tester) async {
      env = await TestEnv.createAtProfileSelect(tester);

      expect(find.byType(SelectProfileScreen), findsOneWidget);
      expect(find.textContaining('My Health'), findsWidgets);
    });

    testWidgets('Profile selection shows access level badge', (tester) async {
      env = await TestEnv.createAtProfileSelect(tester);

      // Should show OWNER badge
      expect(find.textContaining('OWNER'), findsOneWidget);
    });

    testWidgets('Profile selection shows age and gender', (tester) async {
      env = await TestEnv.createAtProfileSelect(tester);

      expect(find.textContaining('65'), findsWidgets);
      expect(find.textContaining('Male'), findsWidgets);
    });

    testWidgets('Add profile button exists', (tester) async {
      env = await TestEnv.createAtProfileSelect(tester);

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Add profile navigates to create profile screen', (
      tester,
    ) async {
      env = await TestEnv.createAtProfileSelect(tester);

      // Find and tap the add profile button
      await scrollUntilVisible(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await pumpN(tester, frames: 5);

      expect(find.byType(CreateProfileScreen), findsOneWidget);
    });

    testWidgets('Create profile screen has name field and submit button', (
      tester,
    ) async {
      env = await TestEnv.create(
        tester,
        startScreen: const CreateProfileScreen(),
      );

      expect(find.byType(CreateProfileScreen), findsOneWidget);
      expect(profileName, findsOneWidget);

      await scrollUntilVisible(tester, profileCreateButton);
      expect(profileCreateButton, findsOneWidget);
    });

    testWidgets('Create profile validates empty name', (tester) async {
      env = await TestEnv.create(
        tester,
        startScreen: const CreateProfileScreen(),
      );

      await scrollUntilVisible(tester, profileCreateButton);
      await tester.tap(profileCreateButton, warnIfMissed: false);
      await pumpN(tester);

      // Should still be on create profile (validation failed)
      expect(find.byType(CreateProfileScreen), findsOneWidget);
    });

    testWidgets('Shared profiles section exists', (tester) async {
      env = await TestEnv.createAtProfileSelect(tester);

      // Should show shared profiles section header
      expect(find.textContaining('Shared'), findsWidgets);
    });

    testWidgets('Profile list loads from API', (tester) async {
      env = await TestEnv.createAtProfileSelect(tester);

      expect(env.tracker.hasCalled('GET', '/profiles'), isTrue);
      expect(env.tracker.hasCalled('GET', '/invites/pending'), isTrue);
    });

    // ── Navigation stack cleared after profile selection (new-user regression) ──
    // Regression: pushReplacement left old login routes in the stack so
    // popUntil(isFirst) in ReadingConfirmationScreen landed on login instead
    // of ShellScreen. Fix: pushAndRemoveUntil clears all prior routes.
    testWidgets('Selecting profile clears the navigation stack', (tester) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      await StorageService().saveActiveProfileId(1);

      // Simulate new-user registration stack: [LoginParent, SelectProfileScreen]
      env = await TestEnv.create(
        tester,
        startScreen: _SelectProfileWithParent(),
      );
      await pumpN(tester, frames: 20);

      // Tap on the first profile card
      final profileCard = find.textContaining('My Health');
      expect(profileCard, findsWidgets);
      await tester.tap(profileCard.first);
      await pumpN(tester, frames: 30);

      // After pushAndRemoveUntil, the old "LoginParent" route must be gone.
      // Navigator.canPop() == false means ShellScreen is the root.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse,
          reason: 'Old login routes must be cleared after profile selection');
    });
  });
}

/// Wraps SelectProfileScreen inside a fake "login" parent route so the
/// test stack mirrors the real new-user registration flow:
///   [UnifiedLoginScreen (isFirst), SelectProfileScreen]
class _SelectProfileWithParent extends StatefulWidget {
  const _SelectProfileWithParent();
  @override
  State<_SelectProfileWithParent> createState() => _SelectProfileWithParentState();
}

class _SelectProfileWithParentState extends State<_SelectProfileWithParent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const SelectProfileScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('LoginParent')));
}
