enum Flavor {
  staging(
    serverHost: 'https://65.109.226.36:8443',
    displayName: 'Swasth Staging',
  ),
  production(serverHost: 'https://65.109.226.36:8444', displayName: 'Swasth');

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
