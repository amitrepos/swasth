import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier(Locale initialLocale) : super(initialLocale);

  Future<void> setLanguage(String languageCode) async {
    await StorageService().saveLanguage(languageCode);
    state = Locale(languageCode);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>(
  (ref) => LanguageNotifier(const Locale('en')), // default; overridden in main()
);
