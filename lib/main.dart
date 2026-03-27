import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'providers/language_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final langCode = await StorageService().getLanguage() ?? 'en';
  runApp(
    ProviderScope(
      overrides: [
        languageProvider.overrideWith(
          (ref) => LanguageNotifier(Locale(langCode)),
        ),
      ],
      child: const SwasthApp(),
    ),
  );
}

class SwasthApp extends ConsumerWidget {
  const SwasthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    const double borderRadiusValue = 16.0;
    const Color iosSystemBlue = Color(0xFF007AFF);
    
    // LIGHT THEME
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: iosSystemBlue,
      primary: iosSystemBlue,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      brightness: Brightness.light,
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
        displaySmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.inter(fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          side: const BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iosSystemBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusValue),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: iosSystemBlue, width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    // DARK THEME
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: iosSystemBlue,
      primary: iosSystemBlue,
      onPrimary: Colors.white,
      surface: const Color(0xFF1C1C1E),
      onSurface: Colors.white,
      brightness: Brightness.dark,
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: Colors.black,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        displaySmall: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, color: Colors.white70),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, color: Colors.white70),
        bodySmall: GoogleFonts.inter(fontWeight: FontWeight.w400, color: Colors.white70),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1C1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          side: const BorderSide(color: Color(0xFF38383A), width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iosSystemBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusValue),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: Color(0xFF38383A), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: Color(0xFF38383A), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: iosSystemBlue, width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    return MaterialApp(
      title: 'Swasth',
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const LoginScreen(),
    );
  }
}