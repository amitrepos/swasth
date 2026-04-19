import 'dart:io'
    show HttpClient, HttpOverrides, SecurityContext, X509Certificate;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/flavor.dart';
import 'providers/language_provider.dart';
import 'services/reminder_service.dart';
import 'services/storage_service.dart';

/// Trusts the pilot backend's self-signed TLS cert on mobile builds ONLY.
///
/// Both staging (:8443) and production (:8444) run on 65.109.226.36 with a
/// self-signed certificate. Browsers let users click past the warning, but
/// `dart:io`'s HttpClient hard-rejects it with
/// `CERTIFICATE_VERIFY_FAILED: self signed certificate`, breaking every API
/// call from the Android/iOS app.
///
/// This override is **scoped to that single host** — every other host still
/// goes through the normal TLS trust chain. Before public GA the server must
/// get a real cert (Let's Encrypt + domain) and this class must be deleted.
class _PilotHttpOverrides extends HttpOverrides {
  static const _pilotHost = '65.109.226.36';

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => host == _pilotHost;
  }
}

/// Shared app startup. Each flavor's entry point calls this with its Flavor
/// value — encodes the server URL + display name at compile time, removing the
/// need for `--dart-define=SERVER_HOST=...` at build time.
///
/// Wraps the bootstrap sequence in a try/catch so a failure in early init
/// (secure storage unavailable, notification permission denied on some Android
/// variants, dotenv corrupted asset) doesn't crash the app with a native OS
/// dialog before any Flutter surface has rendered — the user would see a
/// black screen and close the app. We instead render a minimal branded error
/// screen with a retry affordance.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  Flavor.set(flavor);

  if (!kIsWeb) {
    HttpOverrides.global = _PilotHttpOverrides();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  try {
    await _init(flavor);
  } catch (e, stack) {
    debugPrint('bootstrap failed: $e\n$stack');
    runApp(_BootstrapErrorApp(onRetry: () => bootstrap(flavor)));
  }
}

Future<void> _init(Flavor flavor) async {
  // .env is a **debug-only** override for local dev (e.g. SERVER_HOST pointing
  // at a local backend). Release builds ignore .env — see AppConfig.serverHost
  // for rationale. The file is still loaded here so other dotenv-backed
  // values (if any) stay available; only the SERVER_HOST lookup is gated.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env file — fine. Flavor's serverHost wins.
  }

  await ReminderService().initialize();
  final langCode = await StorageService().getLanguage() ?? 'en';

  runApp(
    ProviderScope(
      overrides: [
        languageProvider.overrideWith(() => LanguageNotifier(Locale(langCode))),
      ],
      child: const SwasthApp(),
    ),
  );
}

/// Minimal, localization-free fallback app shown when bootstrap throws before
/// the main app (and its AppLocalizations) can load. Keep this widget
/// dependency-free — no Riverpod, no l10n, no theme extensions — because
/// whatever broke bootstrap probably affects one of those too.
class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Swasth',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "We couldn't start the app.\n"
                    "कुछ गड़बड़ हुई. ऐप नहीं खुल पाया.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Text(
                        'Try again / फिर कोशिश करें',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
