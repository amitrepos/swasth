// Unit tests for RegionService auth-header injection (NUO-135 follow-up).
//
// Covers the three branches of the token guard in _fetchAndCache:
//   C-auth-1: token present → Authorization header sent
//   C-auth-2: token null    → no Authorization header
//   C-auth-3: token empty   → no Authorization header (MEDIUM-2 guard)
//   C-auth-4: network error → fail-open (RegionInfo.unknown, writeAllowed=true)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/services/region_service.dart';
import 'package:swasth_app/services/storage_service.dart';

http.Client _regionOk(void Function(http.BaseRequest) onRequest) {
  return MockClient((request) async {
    onRequest(request);
    return http.Response(
      jsonEncode({'country_code': 'IN', 'write_allowed': true, 'source': 'ip'}),
      200,
    );
  });
}

void main() {
  tearDown(() {
    RegionService.setCacheForTest(null);
    ApiClient.httpClientOverride = null;
    StorageService.useRealStorage();
  });

  group('RegionService — auth header injection', () {
    test('C-auth-1: sends Authorization header when token is present', () async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('test-bearer-token');

      http.BaseRequest? captured;
      ApiClient.httpClientOverride = _regionOk((r) => captured = r);

      await RegionService.refresh();

      expect(captured, isNotNull);
      final auth = captured!.headers.entries
          .firstWhere(
            (e) => e.key.toLowerCase() == 'authorization',
            orElse: () => const MapEntry('', ''),
          )
          .value;
      expect(auth, equals('Bearer test-bearer-token'));
    });

    test('C-auth-2: omits Authorization header when token is null', () async {
      StorageService.useInMemoryStorage();
      // No token saved → getToken() returns null

      http.BaseRequest? captured;
      ApiClient.httpClientOverride = _regionOk((r) => captured = r);

      await RegionService.refresh();

      expect(captured, isNotNull);
      final hasAuth = captured!.headers.keys.any(
        (k) => k.toLowerCase() == 'authorization',
      );
      expect(hasAuth, isFalse);
    });

    test('C-auth-3: omits Authorization header when token is empty string',
        () async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('');

      http.BaseRequest? captured;
      ApiClient.httpClientOverride = _regionOk((r) => captured = r);

      await RegionService.refresh();

      expect(captured, isNotNull);
      final hasAuth = captured!.headers.keys.any(
        (k) => k.toLowerCase() == 'authorization',
      );
      expect(hasAuth, isFalse,
          reason: 'empty-string token must not produce Authorization: Bearer');
    });

    test('C-auth-4: resolves to RegionInfo.unknown on network failure (fail-open)',
        () async {
      StorageService.useInMemoryStorage();
      ApiClient.httpClientOverride =
          MockClient((_) async => throw Exception('network down'));

      final result = await RegionService.refresh();

      expect(result.writeAllowed, isTrue,
          reason: 'must fail open so India users are not locked out');
      expect(result.source, equals('unknown'));
    });
  });
}
