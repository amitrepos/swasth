// HTTP service for region detection (NUO-135).
//
// Calls `GET /api/public/region` to learn whether the current caller is
// allowed to write health data (India-only by product rule). The result
// is cached in-memory for the process lifetime — we don't want to
// hammer the backend on every screen rebuild, and the user's geo
// doesn't change between login and logout.
//
// The endpoint is unauthenticated by design so we can render the
// read-only banner on the login screen itself.
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../config/app_config.dart';
import 'api_client.dart';

class RegionInfo {
  /// ISO-2 country code, or 'UNKNOWN' if we couldn't determine it.
  final String countryCode;

  /// True iff the user is allowed to POST health data / chat / meals.
  final bool writeAllowed;

  /// 'ip' | 'locale' | 'private' | 'disabled' | 'error'. Telemetry only.
  final String source;

  const RegionInfo({
    required this.countryCode,
    required this.writeAllowed,
    required this.source,
  });

  /// Conservative default used while the network request is in-flight.
  /// We default to **allowed** because the master switch is off in
  /// dev/CI and we don't want to flash a "read-only" banner during
  /// the first 500ms of every cold start.
  static const RegionInfo unknown = RegionInfo(
    countryCode: 'UNKNOWN',
    writeAllowed: true,
    source: 'unknown',
  );

  factory RegionInfo.fromJson(Map<String, dynamic> json) => RegionInfo(
        countryCode: (json['country_code'] ?? 'UNKNOWN') as String,
        writeAllowed: (json['write_allowed'] ?? json['is_india'] ?? true) as bool,
        source: (json['source'] ?? 'unknown') as String,
      );
}

class RegionService {
  static RegionInfo? _cached;
  static Future<RegionInfo>? _inflight;

  /// Returns the cached region info if we've already fetched it, otherwise
  /// fetches once and memoises. Never throws — failures resolve to
  /// `RegionInfo.unknown` (write-allowed) so we fail open.
  static Future<RegionInfo> getRegion() async {
    if (_cached != null) return _cached!;
    if (_inflight != null) return _inflight!;
    _inflight = _fetchAndCache();
    return _inflight!;
  }

  /// Synchronous accessor for widgets that want to react to the latest
  /// fetched value. Returns `unknown` until [getRegion] resolves.
  static RegionInfo currentOrUnknown() => _cached ?? RegionInfo.unknown;

  /// Force a refetch (useful after auth changes or when the user
  /// reports the banner is wrong). Safe to call repeatedly.
  static Future<RegionInfo> refresh() async {
    _cached = null;
    _inflight = null;
    return getRegion();
  }

  static Future<RegionInfo> _fetchAndCache() async {
    try {
      final body = await ApiClient.sendJsonObject(
        () => ApiClient.httpClient.get(
          Uri.parse('${AppConfig.serverHost}/api/public/region'),
          headers: {
            ..._localeHeader(),
          },
        ),
      );
      _cached = RegionInfo.fromJson(body);
    } catch (_) {
      // Fail open — better to allow writes than to lock out India users
      // because of a backend hiccup. The server-side dependency will
      // still reject if they're actually outside India.
      _cached = RegionInfo.unknown;
    } finally {
      _inflight = null;
    }
    return _cached!;
  }

  static Map<String, String> _localeHeader() {
    // Send the device locale so the server's locale-fallback works on
    // private/loopback addresses — important for mobile data + carrier
    // NAT scenarios where the egress IP is non-deterministic.
    try {
      final locale = PlatformDispatcher.instance.locale;
      final tag = '${locale.languageCode}${locale.countryCode != null ? '-${locale.countryCode}' : ''}';
      if (tag.isEmpty) return const {};
      return {'Accept-Language': tag};
    } catch (_) {
      if (!kIsWeb) {
        try {
          return {'Accept-Language': Platform.localeName.replaceAll('_', '-')};
        } catch (_) {}
      }
      return const {};
    }
  }
}
