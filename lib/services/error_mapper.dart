import 'package:flutter/material.dart';
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
///   * [showSnack] — side-effecting helper. Shows a SnackBar and, if the
///     exception is [UnauthorizedException], clears session storage and
///     navigates to the login route. This is the 401 interceptor.
///
/// Screens MUST use one of these. Never `Text(e.toString())` — that path
/// leaks `SocketException: Failed host lookup` to the user.
class ErrorMapper {
  const ErrorMapper._();

  /// Named login route. Any screen that wants to override the destination
  /// on 401 can do so by calling [showSnack] with its own [loginRoute].
  static const String defaultLoginRoute = '/login';

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

  /// Show a SnackBar with the mapped message. On [UnauthorizedException],
  /// additionally clear session storage and reset the navigation stack to
  /// the login route — this is the single place app-wide 401 handling lives.
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );

    if (error is UnauthorizedException) {
      // Terminal session event — wipe token and bounce to login so the
      // user isn't stuck tapping retry on an already-revoked session.
      await StorageService().clearAll();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(loginRoute, (_) => false);
    }
  }
}
