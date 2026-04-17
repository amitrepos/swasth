import 'dart:io'
    show HttpClient, HttpOverrides, SecurityContext, X509Certificate;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  // .env remains an optional override for local dev (dotenv.env['SERVER_HOST']
  // overrides the flavor's serverHost if set). Asset-bundling-safe: if .env is
  // missing, load() throws, so we swallow that and continue with flavor default.
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
