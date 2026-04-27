enum Flavor {
  staging(
    serverHost: 'https://staging-api.swasth.health',
    displayName: 'Swasth Staging',
  ),
  production(serverHost: 'https://api.swasth.health', displayName: 'Swasth');

  const Flavor({required this.serverHost, required this.displayName});

  final String serverHost;
  final String displayName;

  static Flavor? _current;

  static Flavor get current {
    final f = _current;
    if (f == null) {
      throw StateError(
        'Flavor.current accessed before Flavor.set() — call it from main_staging.dart or main_production.dart before runApp.',
      );
    }
    return f;
  }

  static void set(Flavor flavor) {
    _current = flavor;
  }

  /// Test/reset hook. Do not call from production code.
  static void resetForTesting() {
    _current = null;
  }
}
