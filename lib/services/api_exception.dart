/// Typed API exception hierarchy. Every HTTP service call throws one of
/// these subclasses — never a raw [Exception]. Screens catch the base
/// [ApiException] and hand it to [ErrorMapper] which renders a localized,
/// patient-readable message (no `SocketException: Failed host lookup`
/// strings leaking into SnackBars).
///
/// Replaces the prior pattern where `api_service.dart` double-wrapped every
/// error with `throw Exception('Failed to X: $e')`, producing nested
/// exception strings like
///   "Failed to login: Failed to login: SocketException: ..."
/// that surfaced directly to Sunita on a flaky rural network.
library;

sealed class ApiException implements Exception {
  const ApiException([this.detail]);

  /// Optional server-provided detail string. Safe to show to the user
  /// only when the subclass is [ValidationException] (a trusted 4xx body);
  /// otherwise [ErrorMapper] ignores it.
  final String? detail;

  @override
  String toString() =>
      detail == null ? runtimeType.toString() : '$runtimeType: $detail';
}

/// No connectivity, DNS failure, socket timeout, or TLS handshake error.
/// User should be told "no internet — try again" in their language.
class NetworkException extends ApiException {
  const NetworkException();
}

/// Backend returned 401. Token is missing, expired, or revoked. Callers
/// MUST treat this as a terminal session event — clear storage and send
/// the user back to login. [ErrorMapper.showSnack] handles this automatically.
class UnauthorizedException extends ApiException {
  const UnauthorizedException();
}

/// Backend returned 5xx or produced a malformed body we could not parse.
/// User-visible message is always generic — never echo a 500 body.
class ServerException extends ApiException {
  const ServerException([super.detail]);
}

/// Backend returned a 4xx (other than 401) with a safe `detail` message
/// intended for the user — e.g. "Email already registered", "Invalid OTP".
/// These are the only exceptions whose [detail] is safe to surface verbatim.
class ValidationException extends ApiException {
  const ValidationException(String super.detail);
}
