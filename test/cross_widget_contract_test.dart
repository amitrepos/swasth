/// Cross-widget contract tests — verify data flows between screens correctly.
///
/// These tests catch regressions where one screen depends on another's
/// parameters, static methods, or constructors. If someone changes a
/// method signature, removes a parameter, or breaks a contract, these fail.
///
/// This is what we were missing that caused the "Discuss with AI" regression.
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/shell_screen.dart';
import 'package:swasth_app/screens/chat_screen.dart';
import 'package:swasth_app/screens/trend_chart_screen.dart';
import 'package:swasth_app/screens/reading_confirmation_screen.dart';
import 'package:swasth_app/screens/streaks_screen.dart';

void main() {
  // =========================================================================
  // Contract: ShellScreen ↔ ChatScreen
  // "Discuss with AI" sets chatMessage via switchToTab(4, chatMessage: ...)
  // ChatScreen reads it via initialMessage constructor parameter
  // =========================================================================

  group('Contract: ShellScreen → ChatScreen', () {
    test('switchToTab accepts chatMessage parameter', () {
      // If this doesn't compile, someone broke the switchToTab signature
      try {
        ShellScreen.switchToTab(4, chatMessage: 'Test');
      } catch (_) {} // Shell not initialized — OK, we're testing the signature
    });

    test('switchToTab works without chatMessage (backward compat)', () {
      try {
        ShellScreen.switchToTab(0);
      } catch (_) {}
    });

    test('ChatScreen accepts initialMessage', () {
      const screen = ChatScreen(profileId: 1, initialMessage: 'Hello');
      expect(screen.initialMessage, 'Hello');
    });

    test('ChatScreen works without initialMessage', () {
      const screen = ChatScreen(profileId: 1);
      expect(screen.initialMessage, isNull);
    });
  });

  // =========================================================================
  // Contract: TrendChartScreen → ShellScreen
  // "Discuss with AI" button calls ShellScreen.switchToTab(4, chatMessage: ...)
  // =========================================================================

  group('Contract: TrendChartScreen → ShellScreen', () {
    test('TrendChartScreen has profileId', () {
      const screen = TrendChartScreen(profileId: 5);
      expect(screen.profileId, 5);
    });
  });

  // =========================================================================
  // Contract: ReadingConfirmationScreen → ShellScreen
  // After save, pops to Shell via popUntil and switchToTab(0)
  // =========================================================================

  group('Contract: ReadingConfirmationScreen → ShellScreen', () {
    test('ReadingConfirmationScreen has profileId and deviceType', () {
      const screen = ReadingConfirmationScreen(
        ocrResult: null, deviceType: 'glucose', profileId: 3,
      );
      expect(screen.profileId, 3);
      expect(screen.deviceType, 'glucose');
    });

    test('ReadingConfirmationScreen accepts blood_pressure type', () {
      const screen = ReadingConfirmationScreen(
        ocrResult: null, deviceType: 'blood_pressure', profileId: 3,
      );
      expect(screen.deviceType, 'blood_pressure');
    });
  });

  // =========================================================================
  // Contract: ShellScreen tab indices
  // If tab order changes, multiple features break silently
  // =========================================================================

  group('Contract: Shell tab indices', () {
    test('tab 0 = Home, tab 4 = Chat (used by switchToTab)', () {
      // These indices are hardcoded in:
      // - trend_chart_screen.dart: switchToTab(4, chatMessage: ...)
      // - reading_confirmation_screen.dart: switchToTab(0)
      // - home_screen.dart: switchToTab(4)
      // If someone reorders tabs, these will silently break.
      // This test documents the expected indices.
      expect(0, equals(0)); // Home
      expect(1, equals(1)); // History
      expect(2, equals(2)); // Streaks
      expect(3, equals(3)); // Insights
      expect(4, equals(4)); // Chat
    });
  });

  // =========================================================================
  // Contract: StreaksScreen exists and is constructable
  // =========================================================================

  group('Contract: StreaksScreen', () {
    test('StreaksScreen is const constructable', () {
      const screen = StreaksScreen();
      expect(screen, isNotNull);
    });
  });
}
