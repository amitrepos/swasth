import 'dart:math' show min;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swasth_app/l10n/app_localizations.dart';

import 'providers/language_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

/// Global observer — HomeScreen subscribes to know when it becomes active again.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// On Flutter Web, content uses the full viewport up to this width, then stays centered
/// (typical web app column — avoids ultra-wide stretching while not feeling like a phone shell).
const double _kWebMaxContentWidth = 1280;

class SwasthApp extends ConsumerWidget {
  const SwasthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);
    const double borderRadiusValue = 16.0;
    const Color skyAccent = AppColors.primary; // #0EA5E9 sky-500

    final colorScheme = ColorScheme.fromSeed(
      seedColor: skyAccent,
      primary: skyAccent,
      onPrimary: Colors.white,
      surface: AppColors.bgPage,
      onSurface: AppColors.textPrimary,
      brightness: Brightness.light,
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgPage,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        titleSmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        bodyLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: AppColors.glassShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusValue),
          side: const BorderSide(color: AppColors.separator, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: skyAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusValue),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: skyAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );

    return MaterialApp(
      title: 'Swasth',
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      navigatorObservers: [routeObserver],
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();

        final size = MediaQuery.sizeOf(context);
        final contentMaxWidth = min(size.width, _kWebMaxContentWidth);

        return ColoredBox(
          color: AppColors.bgPage,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: contentMaxWidth,
                minHeight: size.height,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
