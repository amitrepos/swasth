import 'package:flutter/material.dart';

/// Apple Health-inspired color palette for Swasth app.
/// All values match iOS system exact colors.
abstract final class AppColors {
  // ── iOS system exact colors ─────────────────────────────────────────────
  static const Color iosBlue    = Color(0xFF007AFF);
  static const Color iosRed     = Color(0xFFFF2D55);   // Apple Health heart/BP
  static const Color iosOrange  = Color(0xFFFF9F0A);   // Apple Health glucose
  static const Color iosGreen   = Color(0xFF30D158);   // Apple Health activity/normal
  static const Color iosPurple  = Color(0xFFBF5AF2);
  static const Color iosTeal    = Color(0xFF32ADE6);

  // ── Semantic health metric colors ───────────────────────────────────────
  static const Color glucose       = iosOrange;
  static const Color bloodPressure = iosRed;
  static const Color scoreHealthy  = iosGreen;

  // ── Status badge colors ─────────────────────────────────────────────────
  static const Color statusNormal   = iosGreen;
  static const Color statusElevated = iosOrange;
  static const Color statusHigh     = iosRed;
  static const Color statusCritical = iosRed;
  static const Color statusLow      = Color(0xFF636366); // iOS system gray

  // ── Surfaces — light ────────────────────────────────────────────────────
  static const Color bgPrimary  = Color(0xFFF2F2F7); // iOS gray-6
  static const Color bgCard     = Color(0xFFFFFFFF);
  static const Color bgGrouped  = Color(0xFFE5E5EA); // iOS gray-5

  // ── Surfaces — dark ─────────────────────────────────────────────────────
  static const Color bgPrimaryDark = Color(0xFF000000);
  static const Color bgCardDark    = Color(0xFF1C1C1E);
  static const Color bgGroupedDark = Color(0xFF2C2C2E);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF8E8E93); // iOS system gray
  static const Color textTertiary  = Color(0xFFC7C7CC); // iOS system gray-3

  // ── Separators ──────────────────────────────────────────────────────────
  static const Color separator     = Color(0xFFC6C6C8);
  static const Color separatorDark = Color(0xFF38383A);
}
