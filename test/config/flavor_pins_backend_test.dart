// Pins the flavor → backend URL mapping. If these URLs need to change, update
// [Flavor] and this test together. The release-mode invariant (flavor is the
// sole source of truth, .env / --dart-define ignored) is enforced by the
// `kReleaseMode` gate in [AppConfig.serverHost] — a compile-time constant, so
// Dart tree-shakes the override branch out of release builds. Unit tests run
// in debug mode; we assert the fallback path lands on the correct flavor URL
// when no override is set.

import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/config/app_config.dart';
import 'package:swasth_app/config/flavor.dart';

void main() {
  // dotenv is intentionally not initialised — AppConfig catches the resulting
  // NotInitializedError and falls through to Flavor.current, which is what we
  // want to pin here.

  tearDown(() {
    Flavor.resetForTesting();
  });

  test('Flavor.production → production backend (AWS)', () {
    Flavor.set(Flavor.production);
    expect(AppConfig.serverHost, 'https://api.swasth.health');
  });

  test('Flavor.staging → staging backend (AWS)', () {
    Flavor.set(Flavor.staging);
    expect(AppConfig.serverHost, 'https://staging-api.swasth.health');
  });

  test('staging and production backends are different hosts', () {
    expect(
      Flavor.staging.serverHost,
      isNot(equals(Flavor.production.serverHost)),
      reason:
          'If staging and production point at the same backend, the whole '
          'flavor-pinning model collapses — they must diverge.',
    );
  });
}
