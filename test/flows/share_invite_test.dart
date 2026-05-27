// E2E coverage for the "Invite friends" tile on the Profile screen.
// RULE: never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/profile_screen.dart';
import 'package:swasth_app/services/share_service.dart';
import 'package:swasth_app/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  group('Share invite — ShareService.inviteUrl', () {
    test('inviteUrl ends with /invite and contains no double slashes', () {
      final url = ShareService.inviteUrl();
      expect(url.endsWith('/invite'), isTrue,
          reason: 'Share URL must end with /invite (it is the smart-redirect path).');
      // No double-slash between scheme and path (catches a regression where
      // AppConfig.serverHost stops stripping trailing slashes).
      final pathPart = url.replaceFirst(RegExp(r'^https?://'), '');
      expect(pathPart.contains('//'), isFalse,
          reason: 'inviteUrl produced a // between host and path: $url');
    });
  });

  // Reviewer M3: the previous version of this test rendered a bare
  // ListTile and asserted the tap handler fired. That never exercised
  // the real integration — a regression that moved the tile outside
  // the `if (isOwner)` guard or onto a non-owner profile would not be
  // caught. These tests now pump the REAL ProfileScreen with a
  // mocked owner profile and verify the tile actually appears on
  // screen, then exercises the share_plus platform channel via a
  // method-channel handler so we can also assert the share is
  // dispatched without throwing.
  group('Share invite — tile on real ProfileScreen', () {
    late TestEnv env;

    // share_plus calls the `dev.fluttercommunity.plus/share` platform
    // channel. There is no real Android intent on the test host; we
    // install a handler that records each call and returns a success
    // result so Share.share() resolves cleanly.
    final List<MethodCall> recordedShareCalls = [];
    const shareChannel =
        MethodChannel('dev.fluttercommunity.plus/share');

    setUp(() async {
      recordedShareCalls.clear();
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
        recordedShareCalls.add(call);
        // share_plus historically returns either a String or a Map.
        // A non-null result keeps the future from completing with
        // null (which Dart's null-safety analysis would flag).
        return 'dev.fluttercommunity.plus.share';
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
      env.dispose();
    });

    testWidgets('Tile is rendered on the owner profile', (tester) async {
      // Seed token + userData so ProfileScreen._loadData succeeds.
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_for_test');
      await StorageService().saveUserData({
        'id': 1,
        'email': 'owner@swasth.test',
        'full_name': 'Test Owner',
      });

      env = await TestEnv.create(
        tester,
        startScreen: const ProfileScreen(profileId: 1),
      );
      // ProfileScreen issues a few async loads (profile + linked
      // doctors); give them time to settle.
      await pumpN(tester, frames: 30);

      // Scroll the profile body to where Account Settings lives.
      // Done via the tile's Key — Flutter's scrollUntilVisible walks
      // the closest Scrollable until the target is in view.
      final tile = find.byKey(const Key('profile_invite_friends'));
      await tester.scrollUntilVisible(
        tile,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(tile, findsOneWidget,
          reason: 'Invite tile must render for owner — if this fails, '
              'the isOwner guard on _buildSection has regressed.');

      // Localized strings appear via AppLocalizations.
      expect(find.text('Invite friends'), findsOneWidget);
      expect(find.text('Share Swasth via WhatsApp or SMS'), findsOneWidget);
    });

    testWidgets('Tap dispatches to the share platform channel', (tester) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_for_test');
      await StorageService().saveUserData({
        'id': 1,
        'email': 'owner@swasth.test',
        'full_name': 'Test Owner',
      });

      env = await TestEnv.create(
        tester,
        startScreen: const ProfileScreen(profileId: 1),
      );
      await pumpN(tester, frames: 30);

      final tile = find.byKey(const Key('profile_invite_friends'));
      await tester.scrollUntilVisible(
        tile,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // Tap and let the async share complete.
      await tester.tap(tile);
      await pumpN(tester, frames: 15);

      // share_plus uses one of several method names depending on
      // version ("share", "shareWithResult"). Any of them counts.
      expect(recordedShareCalls.isNotEmpty, isTrue,
          reason: 'Tapping the tile must dispatch to the share platform '
              'channel. Got no calls — ShareService.shareInvite may not be '
              'wired to ListTile.onTap.');
      final call = recordedShareCalls.first;
      expect(call.method, anyOf('share', 'shareWithResult'),
          reason: 'Unexpected share_plus method: ${call.method}');

      // The invite URL must be in the dispatched payload.
      final args = call.arguments as Map?;
      final text = (args?['text'] as String?) ?? '';
      expect(text.contains('/invite'), isTrue,
          reason: 'Dispatched share text did not contain the invite URL: $text');
    });
  });
}
