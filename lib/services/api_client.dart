import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException, HttpException, SocketException;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Shared HTTP utilities used by all API service classes.
class ApiClient {
  /// Override this in tests to inject a MockClient.
  /// When non-null, all service HTTP calls use this client.
  @visibleForTesting
  static http.Client? httpClientOverride;

  /// Returns the HTTP client to use — test override or default.
  static http.Client get httpClient => httpClientOverride ?? http.Client();

  /// Default per-request timeout. Balances slow-3G rural connectivity
  /// against users thinking the app is frozen.
  static const Duration defaultTimeout = Duration(seconds: 20);

  /// Builds standard JSON headers, with an optional Bearer token.
  static Map<String, String> headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Extracts the `detail` field from a non-success response body.
  /// Falls back to [fallback] if the field is missing or the body is malformed.
  ///
  /// FastAPI returns `detail` as a LIST on 422 pydantic validation errors
  /// (`[{loc, msg, type}, ...]`), not as a string. We don't try to
  /// reconstruct a user-readable message from that structure here — the
  /// screen layer via [ErrorMapper] falls through to the generic error
  /// string instead. Don't echo raw pydantic ValidationError dicts to
  /// users; they read "field required; loc=(body,email)" which is
  /// worse than "Something went wrong".
  static String errorDetail(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return fallback;
      final detail = body['detail'];
      if (detail is String) return detail;
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Executes an HTTP request, translating every outcome into either a
  /// [http.Response] (for success) or a typed [ApiException] subclass.
  ///
  /// This is the single point where low-level `dart:io` and status-code
  /// semantics get translated into the app's exception vocabulary.
  /// Services MUST use this instead of calling `httpClient` directly —
  /// otherwise the error-mapping guarantees break.
  ///
  /// * 2xx in [successCodes] → returns the [http.Response]
  /// * 401 → [UnauthorizedException] (triggers auto-logout in ErrorMapper)
  /// * 4xx (other than 401) → [ValidationException] with server detail
  /// * 5xx → [ServerException] with server detail
  /// * [SocketException] / [TimeoutException] / [HandshakeException] /
  ///   [HttpException] → [NetworkException]
  /// * Any other exception → [ServerException]
  static Future<http.Response> send(
    Future<http.Response> Function() request, {
    Duration timeout = defaultTimeout,
    Iterable<int> successCodes = const [200, 201, 204],
  }) async {
    http.Response response;
    try {
      response = await request().timeout(timeout);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException();
    } on HandshakeException {
      throw const NetworkException();
    } on HttpException {
      throw const NetworkException();
    } on ApiException {
      rethrow;
    } catch (_) {
      // Unknown transport-level error. Treat as server-ish rather than
      // network — we couldn't classify it, and "server trouble" is the
      // right message for the user.
      throw const ServerException();
    }

    if (successCodes.contains(response.statusCode)) return response;
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode >= 500) {
      throw ServerException(errorDetail(response, ''));
    }
    if (response.statusCode >= 400) {
      throw ValidationException(errorDetail(response, 'Request failed.'));
    }
    // 1xx / 3xx unexpected — treat as server-ish.
    throw ServerException(errorDetail(response, ''));
  }

  /// Convenience: like [send] but also JSON-decodes the body. Throws
  /// [ServerException] on a malformed body.
  static Future<Map<String, dynamic>> sendJsonObject(
    Future<http.Response> Function() request, {
    Duration timeout = defaultTimeout,
    Iterable<int> successCodes = const [200, 201],
  }) async {
    final response = await send(
      request,
      timeout: timeout,
      successCodes: successCodes,
    );
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ServerException();
      }
      return decoded;
    } on FormatException {
      throw const ServerException();
    }
  }

  /// Like [sendJsonObject] but decodes a JSON list.
  static Future<List<dynamic>> sendJsonList(
    Future<http.Response> Function() request, {
    Duration timeout = defaultTimeout,
    Iterable<int> successCodes = const [200],
  }) async {
    final response = await send(
      request,
      timeout: timeout,
      successCodes: successCodes,
    );
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const ServerException();
      }
      return decoded;
    } on FormatException {
      throw const ServerException();
    }
  }
}
