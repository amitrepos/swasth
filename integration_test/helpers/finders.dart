// Common widget finders for E2E tests.
// Uses Key-based lookups (fast, stable) with text-based fallbacks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Auth screens ────────────────────────────────────────────────────────────

final loginEmail = find.byKey(const Key('login_email'));
final loginPassword = find.byKey(const Key('login_password'));
final loginButton = find.byKey(const Key('login_button'));
final loginRegisterLink = find.byKey(const Key('login_register_link'));

final regFullName = find.byKey(const Key('reg_full_name'));
final regEmail = find.byKey(const Key('reg_email'));
final regPhone = find.byKey(const Key('reg_phone'));
final regPassword = find.byKey(const Key('reg_password'));
final regConfirmPassword = find.byKey(const Key('reg_confirm_password'));
final regAge = find.byKey(const Key('reg_age'));
final regSubmit = find.byKey(const Key('reg_submit_button'));

// ── Profile ─────────────────────────────────────────────────────────────────

final profileName = find.byKey(const Key('profile_name'));
final profileCreateButton = find.byKey(const Key('profile_create_button'));

// ── Shell navigation ────────────────────────────────────────────────────────

final navHome = find.byKey(const Key('nav_home'));
final navHistory = find.byKey(const Key('nav_history'));
final navStreaks = find.byKey(const Key('nav_streaks'));
final navInsights = find.byKey(const Key('nav_insights'));
final navChat = find.byKey(const Key('nav_chat'));

// ── Reading input ───────────────────────────────────────────────────────────

final readingScanCamera = find.byKey(const Key('reading_scan_camera'));
final readingBluetooth = find.byKey(const Key('reading_bluetooth'));
final readingManualEntry = find.byKey(const Key('reading_manual_entry'));
final readingSystolic = find.byKey(const Key('reading_systolic'));
final readingDiastolic = find.byKey(const Key('reading_diastolic'));
final readingPulse = find.byKey(const Key('reading_pulse'));
final readingGlucoseValue = find.byKey(const Key('reading_glucose_value'));
final readingSaveButton = find.byKey(const Key('reading_save_button'));

// ── Meal logging ────────────────────────────────────────────────────────────

final mealQuickSelectOption = find.byKey(const Key('meal_quick_select_option'));
final mealScanPhotoOption = find.byKey(const Key('meal_scan_photo_option'));
final mealHighCarb = find.byKey(const Key('meal_high_carb'));
final mealLowCarb = find.byKey(const Key('meal_low_carb'));
final mealSweets = find.byKey(const Key('meal_sweets'));

// ── Helper: wait for widget then tap ────────────────────────────────────────

/// Taps a widget found by [finder], pumps, and settles.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Enters text into a field found by [finder], pumps, and settles.
Future<void> enterTextAndSettle(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

/// Scrolls until [finder] is visible, then returns it.
Future<void> scrollUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
  double delta = -200,
}) async {
  final scroll = scrollable ?? find.byType(Scrollable).first;
  await tester.scrollUntilVisible(finder, delta, scrollable: scroll);
  await tester.pumpAndSettle();
}
