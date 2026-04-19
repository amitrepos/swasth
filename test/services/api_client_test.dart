// Unit tests for the ApiClient.send/sendJsonObject/sendJsonList helpers.
// These are the single point where transport-level errors and non-2xx
// status codes get translated into the typed ApiException hierarchy.
// If these guarantees break, every screen's error message will silently
// regress. Dedicated unit coverage is cheap and worth it.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/api_exception.dart';

http.Response _resp(int status, [String body = '{}']) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

MockClient _client(Future<http.Response> Function(http.Request) handler) =>
    MockClient(handler);

void main() {
  tearDown(() {
    ApiClient.httpClientOverride = null;
  });

  group('ApiClient.send — status code translation', () {
    test('returns response on 200', () async {
      ApiClient.httpClientOverride = _client((_) async => _resp(200));
      final res = await ApiClient.send(
        () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
      );
      expect(res.statusCode, 200);
    });

    test('returns response on a custom success code', () async {
      ApiClient.httpClientOverride = _client((_) async => _resp(201));
      final res = await ApiClient.send(
        () => ApiClient.httpClient.post(Uri.parse('http://x/y')),
        successCodes: const [201],
      );
      expect(res.statusCode, 201);
    });

    test('throws UnauthorizedException on 401', () async {
      ApiClient.httpClientOverride = _client(
        (_) async => _resp(401, '{"detail":"expired"}'),
      );
      expect(
        () => ApiClient.send(
          () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws ValidationException on 400 with server detail', () async {
      ApiClient.httpClientOverride = _client(
        (_) async => _resp(400, '{"detail":"Email already registered"}'),
      );
      await expectLater(
        ApiClient.send(
          () => ApiClient.httpClient.post(Uri.parse('http://x/y')),
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.detail,
            'detail',
            'Email already registered',
          ),
        ),
      );
    });

    test(
      'throws ValidationException on 409 with fallback when body empty',
      () async {
        ApiClient.httpClientOverride = _client((_) async => _resp(409, ''));
        await expectLater(
          ApiClient.send(
            () => ApiClient.httpClient.post(Uri.parse('http://x/y')),
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.detail,
              'detail',
              'Request failed.',
            ),
          ),
        );
      },
    );

    test('throws ServerException on 500', () async {
      ApiClient.httpClientOverride = _client((_) async => _resp(500, ''));
      expect(
        () => ApiClient.send(
          () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException on 503', () async {
      ApiClient.httpClientOverride = _client((_) async => _resp(503, ''));
      expect(
        () => ApiClient.send(
          () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('ApiClient.send — transport-level errors', () {
    test('throws NetworkException on SocketException', () async {
      ApiClient.httpClientOverride = _client(
        (_) async => throw const SocketException('no dns'),
      );
      expect(
        () => ApiClient.send(
          () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test(
      'throws NetworkException on TimeoutException (from .timeout())',
      () async {
        ApiClient.httpClientOverride = _client((_) async {
          // Delay longer than the test-supplied timeout.
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _resp(200);
        });
        expect(
          () => ApiClient.send(
            () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('throws NetworkException on HandshakeException', () async {
      ApiClient.httpClientOverride = _client(
        (_) async => throw const HandshakeException('bad cert'),
      );
      expect(
        () => ApiClient.send(
          () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws NetworkException on HttpException', () async {
      ApiClient.httpClientOverride = _client(
        (_) async => throw const HttpException('connection closed'),
      );
      expect(
        () => ApiClient.send(
          () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('unknown transport error becomes ServerException', () async {
      ApiClient.httpClientOverride = _client(
        (_) async => throw StateError('something weird'),
      );
      expect(
        () => ApiClient.send(
          () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      'rethrows an already-typed ApiException instead of wrapping',
      () async {
        ApiClient.httpClientOverride = _client(
          (_) async => throw const UnauthorizedException(),
        );
        expect(
          () => ApiClient.send(
            () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
          ),
          throwsA(isA<UnauthorizedException>()),
        );
      },
    );
  });

  group('ApiClient.sendJsonObject', () {
    test('returns decoded map on 200', () async {
      ApiClient.httpClientOverride = _client(
        (_) async => _resp(200, '{"a":1,"b":"c"}'),
      );
      final body = await ApiClient.sendJsonObject(
        () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
      );
      expect(body, {'a': 1, 'b': 'c'});
    });

    test('throws ServerException on non-JSON body', () async {
      ApiClient.httpClientOverride = _client(
        (_) async => _resp(200, '<!DOCTYPE html>...'),
      );
      expect(
        () => ApiClient.sendJsonObject(
          () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test(
      'throws ServerException when body is a JSON list, not a map',
      () async {
        ApiClient.httpClientOverride = _client(
          (_) async => _resp(200, '[1,2,3]'),
        );
        expect(
          () => ApiClient.sendJsonObject(
            () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
          ),
          throwsA(isA<ServerException>()),
        );
      },
    );
  });

  group('ApiClient.sendJsonList', () {
    test('returns decoded list on 200', () async {
      ApiClient.httpClientOverride = _client(
        (_) async => _resp(200, '[{"id":1},{"id":2}]'),
      );
      final list = await ApiClient.sendJsonList(
        () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
      );
      expect(list.length, 2);
      expect(list[0], {'id': 1});
    });

    test(
      'throws ServerException when body is a JSON map, not a list',
      () async {
        ApiClient.httpClientOverride = _client(
          (_) async => _resp(200, '{"items":[]}'),
        );
        expect(
          () => ApiClient.sendJsonList(
            () => ApiClient.httpClient.get(Uri.parse('http://x/y')),
          ),
          throwsA(isA<ServerException>()),
        );
      },
    );
  });
}
