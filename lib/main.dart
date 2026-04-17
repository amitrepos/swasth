/// Legacy entry point — kept for backward compatibility with:
///   - `flutter run` with no `--target` flag
///   - Tests that import `package:swasth_app/main.dart`
///
/// Production builds use `lib/main_staging.dart` or `lib/main_production.dart`
/// via `flutter build --flavor staging|production --target lib/main_<flavor>.dart`.
///
/// This file defaults to the `staging` flavor so that `flutter run` without any
/// extra flags still works against the pre-prod backend (:8443).
library;

import 'bootstrap.dart';
import 'config/flavor.dart';

// Re-export so existing tests can continue `import 'package:swasth_app/main.dart' show routeObserver;`.
export 'app.dart' show routeObserver, SwasthApp;

void main() => bootstrap(Flavor.staging);
