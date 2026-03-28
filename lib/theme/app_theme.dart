import 'package:flutter/material.dart';

/// Design3 color palette for Swasth app.
/// Dark-navy backgrounds, purple accent, emerald glucose, rose BP.
abstract final class AppColors {
  // ── Base accent colors ──────────────────────────────────────────────────
  static const Color iosBlue    = Color(0xFF7B61FF);   // Design3 primary accent purple
  static const Color iosRed     = Color(0xFFF87171);   // Design3 soft critical red
  static const Color iosOrange  = Color(0xFFFBBF24);   // Design3 amber elevated
  static const Color iosGreen   = Color(0xFF34D399);   // Design3 emerald normal
  static const Color iosPurple  = Color(0xFFA855F7);   // Design3 accent gradient end
  static const Color iosTeal    = Color(0xFF60A5FA);   // Design3 insight blue

  // ── Semantic health metric colors ───────────────────────────────────────
  static const Color glucose       = Color(0xFF34D399);  // emerald (was orange)
  static const Color bloodPressure = Color(0xFFFB7185);  // rose (was hard red)
  static const Color scoreHealthy  = Color(0xFF34D399);  // emerald

  // ── Status badge colors ─────────────────────────────────────────────────
  static const Color statusNormal   = Color(0xFF34D399);  // emerald
  static const Color statusElevated = Color(0xFFFBBF24);  // amber
  static const Color statusHigh     = Color(0xFFF87171);  // soft red
  static const Color statusCritical = Color(0xFFF87171);  // soft red
  static const Color statusLow      = Color(0xFF636366);  // neutral gray (unchanged)

  // ── Surfaces — light ────────────────────────────────────────────────────
  static const Color bgPrimary  = Color(0xFFE8EAF2);  // Design3 bg-page light
  static const Color bgCard     = Color(0xFFFFFFFF);  // unchanged
  static const Color bgGrouped  = Color(0xFFF7F7FC);  // Design3 bg-card2 light

  // ── Surfaces — dark ─────────────────────────────────────────────────────
  static const Color bgPrimaryDark = Color(0xFF0E0E1A);  // Design3 bg-page dark
  static const Color bgCardDark    = Color(0xFF1C1C2E);  // Design3 bg-card dark
  static const Color bgGroupedDark = Color(0xFF22223A);  // Design3 bg-card2 dark

  // ── Text — light ────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF111127);  // dark navy (not pure black)
  static const Color textSecondary = Color(0x80111127);  // 50% opacity of primary
  static const Color textTertiary  = Color(0x47111127);  // 28% opacity of primary

  // ── Text — dark ─────────────────────────────────────────────────────────
  static const Color textPrimaryDark   = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0x80FFFFFF);  // white 50%
  static const Color textTertiaryDark  = Color(0x47FFFFFF);  // white 28%

  // ── Separators ──────────────────────────────────────────────────────────
  static const Color separator     = Color(0x12000000);  // 7% black
  static const Color separatorDark = Color(0x12FFFFFF);  // 7% white

  // ── New Design3 tokens ──────────────────────────────────────────────────
  static const Color accent   = Color(0xFF7B61FF);  // primary accent purple
  static const Color accent2  = Color(0xFFA855F7);  // gradient end
  static const Color insight  = Color(0xFF60A5FA);  // insight blue

  // ── Extended surfaces ───────────────────────────────────────────────────
  static const Color bgCard2     = Color(0xFFF7F7FC);  // light secondary card
  static const Color bgPill      = Color(0xFFEEEEF6);  // light chip/pill bg
  static const Color bgCard2Dark = Color(0xFF22223A);  // dark secondary card
  static const Color bgPillDark  = Color(0xFF252540);  // dark chip/pill bg
}
