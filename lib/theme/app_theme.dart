import 'package:flutter/material.dart';

/// Glassmorphism color palette for Swasth app.
/// Sky-blue backgrounds, frosted-glass cards, emerald success, slate text.
abstract final class AppColors {
  // ── Primary accent ───────────────────────────────────────────────────────
  static const Color primary    = Color(0xFF0EA5E9);  // sky-500 — buttons, rings, accents
  static const Color success    = Color(0xFF10B981);  // emerald-500 — healthy states
  static const Color amber      = Color(0xFFF59E0B);  // amber-500 — streak, points, caution
  static const Color danger     = Color(0xFFEF4444);  // red-500 — critical states

  // ── Semantic health metric colors (clinically meaningful — do not change) ─
  static const Color glucose       = Color(0xFF10B981);  // emerald
  static const Color bloodPressure = Color(0xFFFB7185);  // rose
  static const Color scoreHealthy  = Color(0xFF10B981);  // emerald

  // ── Status badge colors ──────────────────────────────────────────────────
  static const Color statusNormal   = Color(0xFF10B981);  // emerald
  static const Color statusElevated = Color(0xFFF59E0B);  // amber
  static const Color statusHigh     = Color(0xFFEF4444);  // red
  static const Color statusCritical = Color(0xFFEF4444);  // red
  static const Color statusLow      = Color(0xFF64748B);  // slate-500

  // ── Surfaces — light ─────────────────────────────────────────────────────
  static const Color bgPage     = Color(0xFFF0F9FF);  // sky-50 — scaffold background
  static const Color bgCard     = Color(0x73FFFFFF);  // 45% white — glass card fill
  static const Color bgGrouped  = Color(0xFFE0F2FE);  // sky-100 — grouped sections

  // ── Surfaces — dark ──────────────────────────────────────────────────────
  static const Color bgPageDark    = Color(0xFF0C1A2E);  // deep navy
  static const Color bgCardDark    = Color(0x33FFFFFF);  // 20% white on dark
  static const Color bgGroupedDark = Color(0xFF0F2540);  // dark grouped

  // ── Glass card decorative ────────────────────────────────────────────────
  static const Color glassCardBorder = Color(0x80FFFFFF);  // 50% white border
  static const Color glassShadow     = Color(0x0D1F2687);  // soft blue shadow

  // ── Text — light ─────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1E293B);  // slate-800
  static const Color textSecondary = Color(0xFF64748B);  // slate-500
  static const Color textTertiary  = Color(0xFFCBD5E1);  // slate-300

  // ── Text — dark ──────────────────────────────────────────────────────────
  static const Color textPrimaryDark   = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF94A3B8);  // slate-400
  static const Color textTertiaryDark  = Color(0xFF475569);  // slate-600

  // ── Separators ───────────────────────────────────────────────────────────
  static const Color separator     = Color(0x1A000000);  // 10% black
  static const Color separatorDark = Color(0x1AFFFFFF);  // 10% white

  // ── Extended surfaces ────────────────────────────────────────────────────
  static const Color bgPill     = Color(0xFFE0F2FE);  // sky-100 chip/pill bg light
  static const Color bgPillDark = Color(0xFF1E3A5F);  // dark chip/pill bg

  // ── Backwards-compat aliases (used in existing screens — do not remove) ──
  static const Color iosBlue   = primary;
  static const Color iosGreen  = success;
  static const Color iosOrange = amber;
  static const Color iosTeal   = Color(0xFF38BDF8);  // sky-400
  static const Color iosPurple = Color(0xFF818CF8);  // indigo-400 (replaces old purple)
  static const Color iosRed    = danger;
  static const Color accent    = primary;
  static const Color accent2   = Color(0xFF38BDF8);  // sky-400
  static const Color insight   = Color(0xFF38BDF8);  // sky-400
  static const Color bgPrimary    = bgPage;
  static const Color bgPrimaryDark = bgPageDark;
  static const Color bgCard2      = bgGrouped;
  static const Color bgCard2Dark  = bgGroupedDark;
  static const Color bgPill2      = bgPill;
  static const Color bgPill2Dark  = bgPillDark;
}
