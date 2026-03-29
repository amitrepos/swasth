import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

class LanguageNotifier extends Notifier<Locale> {
  LanguageNotifier(this._initialLocale);
  final Locale _initialLocale;

  @override
  Locale build() => _initialLocale;

  Future<void> setLanguage(String languageCode) async {
    await StorageService().saveLanguage(languageCode);
    state = Locale(languageCode);
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, Locale>(
  () => LanguageNotifier(const Locale('en')), // default; overridden in main()
);
