// E2E coverage for the "Invite friends" tile on the Profile screen.
// RULE: never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:swasth_app/l10n/app_localizations.dart';
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
    /// position), or fails the test with a state dump if not.
    ///
    /// Seeds storage BEFORE TestEnv.create — matches the existing
    /// TestEnv.createAtProfileSelect pattern. `useInMemoryStorage()`
    /// is idempotent so the call inside `create` does NOT wipe our
    /// seeded token.
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
      // children, so the tile is in the tree even when not yet
      // scrolled into view. Poll independent of viewport position;
      // Linux CI and Windows render slightly different surfaces.
      final settled = await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('profile_invite_friends'), skipOffstage: false)
            .evaluate()
            .isNotEmpty,
        maxFrames: 120,
      );
      if (!settled) {
        // Dump every signal we have about WHY the tile didn't render.
        // CI surfaces this on the failing test's stderr and tells us
        // immediately whether the load failed, isOwner was false, or
        // some other render path was hit.
        final exception = tester.takeException();
        final visibleTexts = find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .where((t) => t != null && t.trim().isNotEmpty)
            .take(40)
            .toList();
        final hasSpinner =
            find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        final hasTile = find
            .byKey(const Key('profile_invite_friends'), skipOffstage: false)
            .evaluate()
            .isNotEmpty;
        fail(
          'ProfileScreen never rendered profile_invite_friends within '
          '120 frames.\n'
          '  takeException: $exception\n'
          '  spinner present: $hasSpinner\n'
          '  tile present:    $hasTile\n'
          '  visible Text widgets: $visibleTexts\n'
          'Likely causes:\n'
          '  - spinner=true → _loadData never completed (mock URL miss,\n'
          '    token reset by TestEnv.create after we seeded it, etc.)\n'
          '  - spinner=false, no tile → load failed (catch fired snackbar)\n'
          '    OR access_level != "owner" so isOwner gated the tile out',
        );
      }
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

      // Reviewer M2: pull strings from AppLocalizations rather than
      // hard-coding the English text. Hard-coded literals here would
      // silently desync if app_en.arb changes (flutter analyze won't
      // catch it). Look up via the live BuildContext on the tile so
      // we always assert the same string the app actually rendered.
      final ctx = tester.element(tile);
      final l10n = AppLocalizations.of(ctx)!;
      expect(
        find.text(l10n.inviteFriendsTile, skipOffstage: false),
        findsOneWidget,
        reason: 'Title text from inviteFriendsTile must render on the tile.',
      );
      expect(
        find.text(l10n.inviteFriendsTileSubtitle, skipOffstage: false),
        findsOneWidget,
        reason:
            'Subtitle from inviteFriendsTileSubtitle must render on the tile.',
      );
    });

    testWidgets(
        'Tile is NOT rendered for non-owner (viewer) profile', (tester) async {
      // Reviewer #3 (M3): the invite tile is owner-only (`if (isOwner)`
      // guard in profile_screen.dart). If that guard is removed or the
      // tile is moved outside the block, a shared/viewer user would be
      // able to "invite friends" using the OWNER's account context —
      // a privacy + identity-confusion bug. Pin the negative case.
      //
      // Override GET /profiles/1 to return access_level: 'viewer',
      // boot ProfileScreen, wait for the load to settle, then assert
      // the tile is absent.
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_for_test');
      await StorageService().saveUserData({
        'id': 1,
        'email': 'viewer@swasth.test',
        'full_name': 'Test Viewer',
      });

      // Build a non-owner response. Keep the shape identical to the
      // default mock_http.dart payload so the screen's load path is
      // exercised the same way — only access_level changes.
      final viewerPayload = http.Response(
        jsonEncode({
          'id': 1,
          'name': 'Shared Profile',
          'relationship': 'parent',
          'age': 65,
          'gender': 'Male',
          'height': 170.0,
          'weight': 75.0,
          'blood_group': 'B+',
          'medical_conditions': const <String>[],
          'phone_number': '918700151250',
          'access_level': 'viewer',
          'doctor_name': null,
          'doctor_whatsapp': null,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-04-01T00:00:00Z',
        }),
        200,
      );

      env = await TestEnv.create(
        tester,
        startScreen: const ProfileScreen(profileId: 1),
        overrides: {'GET /profiles/1': viewerPayload},
      );

      // Wait for the load spinner to clear (proxy for _loadData done).
      // We cannot poll for "tile present" — the tile must be absent.
      // Polling for spinner-gone is the closest deterministic signal.
      final loaded = await _pumpUntil(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        maxFrames: 120,
      );
      expect(loaded, isTrue,
          reason:
              'ProfileScreen never finished loading the viewer profile within '
              '120 frames — check the GET /profiles/1 override.');

      // Extra pumps so any post-load build settles.
      await pumpN(tester, frames: 10);

      // Tile must be absent in the FULL tree (skipOffstage:false), not
      // just the visible viewport.
      expect(
        find.byKey(const Key('profile_invite_friends'), skipOffstage: false),
        findsNothing,
        reason:
            'Invite tile rendered on a viewer profile — the `if (isOwner)` '
            'guard in profile_screen.dart has regressed. Non-owners must '
            'not be able to invite using the owner\'s account context.',
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
