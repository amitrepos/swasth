import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';

/// Wraps `share_plus` for the "Share Swasth with a friend" flow.
///
/// Posts a friendly invite message to the OS share sheet (WhatsApp,
/// SMS, email, etc.). The URL points at the backend's smart-redirect
/// endpoint — see `backend/routes_share.py`. That endpoint resolves
/// to:
///   - Android device → Play Store listing once live (web app today)
///   - iOS device     → App Store listing once live (web app today)
///   - desktop / other → web app at swasth.health
///
/// We do NOT hardcode the Play Store URL here. The smart-redirect
/// indirection lets us flip stores per-environment without an app
/// update — staging → staging-api/invite, prod → api.swasth.health/invite.
class ShareService {
  ShareService._();

  /// Build the invite URL by appending `/invite` to the server host
  /// the app is currently pointed at. AppConfig.serverHost is already
  /// trimmed of any trailing slashes, so a plain concatenation here
  /// always produces a well-formed URL.
  static String inviteUrl() {
    final host = AppConfig.serverHost;
    return '$host/invite';
  }

  /// Show the OS share sheet pre-filled with the invite message.
  /// Returns true if the share completed (any action), false if the
  /// user dismissed the sheet OR if the platform refused to surface
  /// a share sheet (no targets, channel failure, etc.).
  static Future<bool> shareInvite(BuildContext context) async {
    // M3: Avoid force-unwrap if context is missing Localizations (e.g. background/test)
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      debugPrint('ShareService: AppLocalizations not found in context');
      return false;
    }

    final message = '${l10n.inviteShareMessage}\n\n${inviteUrl()}';

    // share_plus can throw on devices that have no share targets at
    // all (e.g. a fresh Android emulator without any messaging apps
    // installed) or when the platform channel hiccups. Without this
    // try/catch the user just sees nothing happen — they can't tell
    // whether their tap registered. Show a SnackBar fallback so the
    // failure mode is visible.
    try {
      final result = await Share.share(
        message,
        subject: l10n.inviteShareSubject,
      );
      // ShareResultStatus.dismissed returns false. Intentional — the
      // share did not "complete" from the user's perspective.
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('ShareService: Share.share threw — $e');
      // Re-fetch ScaffoldMessenger AFTER the await — capturing it
      // before the await would store a reference to a possibly-
      // disposed messenger if the surrounding widget was torn down
      // mid-share (e.g. the user navigated away while the share
      // sheet was open). The context.mounted guard proves the
      // widget is still alive at the moment we look up the messenger,
      // and maybeOf returns null gracefully if the lookup fails.
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(l10n.errGeneric)),
        );
      }
      return false;
    }
  }
}
