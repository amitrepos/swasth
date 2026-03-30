import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'providers/language_provider.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

/// Global observer — HomeScreen subscribes to know when it becomes active again.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final langCode = await StorageService().getLanguage() ?? 'en';
  runApp(
    ProviderScope(
      overrides: [
        languageProvider.overrideWith(
          () => LanguageNotifier(Locale(langCode)),
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
    const Color design3Accent = AppColors.accent; // #7B61FF purple

    // LIGHT THEME
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: design3Accent,
      primary: design3Accent,
      onPrimary: Colors.white,
      surface: AppColors.bgCard,
      onSurface: AppColors.textPrimary,
      brightness: Brightness.light,
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.inter(fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w700),
        titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w700),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.inter(fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          side: const BorderSide(color: AppColors.separator, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: design3Accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusValue),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.bgCard,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: AppColors.separator, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: AppColors.separator, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: design3Accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    // DARK THEME
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: design3Accent,
      primary: design3Accent,
      onPrimary: Colors.white,
      surface: AppColors.bgCardDark,
      onSurface: AppColors.textPrimaryDark,
      brightness: Brightness.dark,
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: AppColors.bgPrimaryDark,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        displaySmall: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, color: Colors.white70),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, color: Colors.white70),
        bodySmall: GoogleFonts.inter(fontWeight: FontWeight.w400, color: Colors.white70),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          side: const BorderSide(color: AppColors.separatorDark, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: design3Accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusValue),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondaryDark,
        backgroundColor: AppColors.bgCardDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: AppColors.separatorDark, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: AppColors.separatorDark, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          borderSide: const BorderSide(color: design3Accent, width: 1.5),
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
      navigatorObservers: [routeObserver],
      home: const LoginScreen(),
    );
  }
}