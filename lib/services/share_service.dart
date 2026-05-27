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
  ///
  /// NOTE on WhatsApp specifically: there is no point opening
  /// `wa.me/?text=…` directly — the OS share sheet on Android already
  /// surfaces WhatsApp as the default share target when WhatsApp is
  /// installed, and lets users pick another channel (SMS, Telegram,
  /// email) without us hardcoding any of them.
  static Future<bool> shareInvite(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
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
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('ShareService: Share.share threw — $e');
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.errGeneric)),
      );
      return false;
    }
  }
}
