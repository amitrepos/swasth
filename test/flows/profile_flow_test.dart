// E2E Test: Profile management flow
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/select_profile_screen.dart';
import 'package:swasth_app/screens/create_profile_screen.dart';

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
  });
}
