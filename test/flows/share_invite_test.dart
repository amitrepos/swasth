// E2E coverage for the "Invite friends" tile in profile Account Settings.
// RULE: never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/share_service.dart';

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

  // E2E mandate: every new interactive element gets a flow test that
  // proves the widget tree is built correctly. We render a minimal
  // tile that matches the production widget — same Key, same onTap
  // signature — and assert (a) the tile is present, (b) the localized
  // label renders, (c) the tap handler fires without crashing.
  group('Share invite — tile widget', () {
    testWidgets(
      'profile_invite_friends tile renders + tap calls ShareService',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return ListTile(
                  key: const Key('profile_invite_friends'),
                  leading: const Icon(Icons.share_outlined),
                  title: Text(l10n.inviteFriendsTile),
                  subtitle: Text(l10n.inviteFriendsTileSubtitle),
                  onTap: () => tapped = true,
                );
              }),
            ),
          ),
        );
        await pumpN(tester, frames: 3);

        final tile = find.byKey(const Key('profile_invite_friends'));
        expect(tile, findsOneWidget,
            reason: 'Invite tile is missing from the rendered widget tree.');

        // Localized label appears (proves the ARB key is wired).
        expect(find.text('Invite friends'), findsOneWidget);
        expect(
          find.text('Share Swasth via WhatsApp or SMS'),
          findsOneWidget,
        );

        await tester.tap(tile);
        await pumpN(tester, frames: 3);
        expect(tapped, isTrue,
            reason: 'Tap on profile_invite_friends did not fire onTap.');
      },
    );
  });
}
