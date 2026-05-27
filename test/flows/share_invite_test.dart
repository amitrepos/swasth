// E2E coverage for the "Invite friends" tile on the Profile screen.
// RULE: never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/profile_screen.dart';
import 'package:swasth_app/services/share_service.dart';
import 'package:swasth_app/services/storage_service.dart';

import '../helpers/test_app.dart';

/// Pump until `predicate` returns true, up to `maxFrames`.
///
/// Hand-rolled because pumpAndSettle is forbidden in this repo (the
/// repeating animations in ProfileScreen hang it for 10 minutes) and
/// the async profile + linked-doctors loads finish at different times
/// across Linux CI and a Windows dev box. Polling for the actual
/// post-condition is the only deterministic option.
Future<bool> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  int maxFrames = 60,
  Duration interval = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(interval);
    if (predicate()) return true;
  }
  return false;
}

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

  // Reviewer M3: previous test built a bare ListTile inside a minimal
  // MaterialApp — never exercised the real integration path through
  // ProfileScreen. A regression that moved the tile outside the
  // `if (isOwner)` guard, or wired the wrong onTap, would not have
  // been caught. These tests now pump the REAL ProfileScreen with a
  // mocked owner profile and assert the tile is present + tapping it
  // dispatches to the share_plus platform channel.
  group('Share invite — tile on real ProfileScreen', () {
    TestEnv? env;

    // share_plus calls the `dev.fluttercommunity.plus/share` platform
    // channel. There is no real Android intent on the test host; we
    // install a handler that records each call and returns success
    // so Share.share() resolves cleanly without throwing.
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
      // env may be null if the test failed before TestEnv.create
      // completed; guard against LateInitializationError.
      env?.dispose();
      env = null;
    });

    /// Boot a ProfileScreen with a seeded token + user, then wait for
    /// the async profile load to settle. Returns once the invite tile
    /// has appeared in the widget tree (regardless of viewport
    /// position), or fails the test with a clear message if not.
    Future<void> bootAndWaitForTile(WidgetTester tester) async {
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

      // skipOffstage: false — SingleChildScrollView builds ALL its
      // children, the tile is in the tree even when not yet scrolled
      // into view. Using skipOffstage: false makes the poll
      // independent of viewport position, which matters because
      // Linux CI and Windows render slightly different surface sizes
      // and the tile may or may not be visible at first paint.
      final settled = await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('profile_invite_friends'), skipOffstage: false)
            .evaluate()
            .isNotEmpty,
        maxFrames: 80,
      );
      expect(
        settled,
        isTrue,
        reason:
            'ProfileScreen never rendered the profile_invite_friends tile '
            'within 80 frames. Either the profile API mock failed, the '
            'isOwner gate regressed, or the tile was renamed/keyed differently.',
      );
    }

    testWidgets('Tile is rendered on the owner profile', (tester) async {
      await bootAndWaitForTile(tester);

      // Off-stage-tolerant find — proves the tile is in the tree
      // whether or not the test viewport scrolled it on screen.
      final tile = find.byKey(
        const Key('profile_invite_friends'),
        skipOffstage: false,
      );
      expect(tile, findsOneWidget,
          reason:
              'Invite tile must render for owner — if this fails the '
              'isOwner guard on _buildSection has regressed.');

      // Localized strings appear via AppLocalizations (also
      // off-stage-tolerant for the same reason).
      expect(
        find.text('Invite friends', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Share Swasth via WhatsApp or SMS', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('Tap dispatches to the share platform channel', (tester) async {
      await bootAndWaitForTile(tester);

      final tile = find.byKey(
        const Key('profile_invite_friends'),
        skipOffstage: false,
      );

      // ensureVisible is the deterministic way to bring an off-stage
      // widget into the hit-test region. scrollUntilVisible needs us
      // to guess which Scrollable to drive; ensureVisible walks the
      // tile's own ancestor chain.
      await tester.ensureVisible(tile);
      await pumpN(tester, frames: 5);

      await tester.tap(tile);
      // Share.share fires the platform call inside an async chain;
      // 25 frames is comfortably enough for Linux CI's slower
      // microtask queue.
      await pumpN(tester, frames: 25);

      expect(recordedShareCalls.isNotEmpty, isTrue,
          reason:
              'Tapping the tile must dispatch to the share platform channel. '
              'Got no calls — ShareService.shareInvite is not wired to '
              'ListTile.onTap, or the channel name changed in share_plus.');
      final call = recordedShareCalls.first;
      expect(call.method, anyOf('share', 'shareWithResult'),
          reason: 'Unexpected share_plus method: ${call.method}');

      // The invite URL must appear in the dispatched payload.
      final args = call.arguments as Map?;
      final text = (args?['text'] as String?) ?? '';
      expect(text.contains('/invite'), isTrue,
          reason: 'Dispatched share text did not contain the invite URL: $text');
    });
  });
}
