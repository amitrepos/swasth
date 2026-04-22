import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import 'api_exception.dart';
import 'storage_service.dart';

/// Central translator between thrown exceptions and user-facing messages.
///
/// Two entry points:
///
///   * [userMessage] — pure function, returns a localized [String].
///     Use when the screen renders the error inline (e.g. `setState(() =>
///     _error = ErrorMapper.userMessage(l10n, e))`).
///
///   * [showSnack] — side-effecting helper. Shows a SnackBar + announces
///     the message to TalkBack/VoiceOver. On [UnauthorizedException] it
///     shows an explicit dialog the user must acknowledge before session
///     storage is cleared and the stack is reset to the login route — the
///     app-wide 401 interceptor.
///
/// Screens MUST use one of these. Never `Text(e.toString())` — that path
/// leaks `SocketException: Failed host lookup` to the user.
class ErrorMapper {
  const ErrorMapper._();

  /// Named login route. Any screen that wants to override the destination
  /// on 401 can do so by calling [showSnack] with its own [loginRoute].
  static const String defaultLoginRoute = '/login';

  /// SnackBar dwell time for error messages. Bumped from the Flutter
  /// default (4s) to 6s because Devanagari reading takes roughly 1.3x
  /// the time of English and elderly users need another ~1.5x on top;
  /// the longer Hindi strings wouldn't finish being read in 4s.
  static const Duration _errorSnackDuration = Duration(seconds: 6);

  /// Pure translation. Returns a plain, elderly-readable localized string.
  /// Safe to call outside a widget context if you already have [l10n].
  static String userMessage(AppLocalizations l10n, Object error) {
    if (error is NetworkException) return l10n.errNetwork;
    if (error is UnauthorizedException) return l10n.errSessionExpired;
    if (error is ValidationException) {
      // ValidationException.detail comes from a 4xx body. Backend is the
      // source of truth; assume the string is already user-friendly.
      // Fall back to generic if somehow empty.
      return error.detail?.isNotEmpty == true ? error.detail! : l10n.errGeneric;
    }
    if (error is ServerException) return l10n.errServer;
    // Any other exception (bug in the app, unexpected code path). Never
    // surface it verbatim — the user can't act on "Bad state: ...".
    return l10n.errGeneric;
  }

  /// Show a SnackBar with the mapped message. Announces to the accessibility
  /// layer so TalkBack/VoiceOver speaks the error. On [UnauthorizedException]
  /// shows a dismiss-blocking dialog the user must acknowledge before we
  /// clear session storage and reset the navigation stack to [loginRoute].
  ///
  /// Caller MUST ensure [context] is still mounted (guard with `!mounted
  /// return;` before calling from async blocks).
  static Future<void> showSnack(
    BuildContext context,
    Object error, {
    Color? backgroundColor,
    String loginRoute = defaultLoginRoute,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final message = userMessage(l10n, error);

    // 401 is a terminal session event. Use a modal instead of a transient
    // SnackBar so the user actually reads "please log in again" before
    // they're bounced to the login screen. Otherwise the SnackBar gets
    // cut off mid-read by the navigation animation.
    if (error is UnauthorizedException) {
      await _showSessionExpiredAndLogout(
        context,
        message: message,
        loginRoute: loginRoute,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: _errorSnackDuration,
      ),
    );
    // Announce to TalkBack/VoiceOver. SnackBars are NOT auto-announced by
    // Flutter's accessibility layer, so users with screen readers would
    // otherwise miss the error entirely.
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  static Future<void> _showSessionExpiredAndLogout(
    BuildContext context, {
    required String message,
    required String loginRoute,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.errSessionExpired),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.loginButton),
          ),
        ],
      ),
    );

    await StorageService().clearAll();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(loginRoute, (_) => false);
  }
}
