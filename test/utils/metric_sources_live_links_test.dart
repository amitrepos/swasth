@Tags(['live'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/utils/metric_ranges.dart';

/// Integration test that actually hits each source URL to confirm it returns
/// HTTP 200. Tagged `live` so it does NOT run in normal CI (which would
/// otherwise flake on transient network failures or be slow). Run on demand:
///
///   flutter test --tags live test/utils/metric_sources_live_links_test.dart
///
/// Also wired into a scheduled CI workflow (.github/workflows/live-link-check.yml)
/// so we hear about a broken source within 24 hours of it dying — long before
/// a user clicks it.
void main() {
  group('MetricSources — live URL check', () {
    // Dedupe — same URL appearing under two SourceRef objects only needs one
    // network call. (icmr.gov.in is shared between BP-HTN and Glucose-DM.)
    final urls = MetricSources.all.map((s) => s.url).toSet();

    for (final url in urls) {
      test('returns 2xx/3xx for $url', () async {
        final code = await _probe(url);
        expect(
          code,
          inInclusiveRange(200, 399),
          reason:
              'Source link is broken — replace with a stable landing page. '
              'Got HTTP $code for $url',
        );
      }, timeout: const Timeout(Duration(seconds: 30)));
    }
  });
}

Future<int> _probe(String url) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = 'Mozilla/5.0 (Swasth live-link checker)';
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.followRedirects = true;
    req.maxRedirects = 5;
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  } on SocketException catch (e) {
    fail('SocketException for $url: ${e.message} (host lookup or refused)');
  } on HandshakeException catch (e) {
    fail('HandshakeException for $url: ${e.message} (TLS / cert problem)');
  } on HttpException catch (e) {
    fail('HttpException for $url: ${e.message}');
  } finally {
    client.close(force: true);
  }
}
