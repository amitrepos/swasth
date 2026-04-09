// E2E Test: Chat flow — send message, get AI response
// RULE: Never use pumpAndSettle — use pumpN() to avoid animation hangs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/screens/chat_screen.dart';

import '../helpers/test_app.dart';
import '../helpers/finders.dart';

void main() {
  group('Chat Flow E2E', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Chat screen renders input and send button', (tester) async {
      env = await TestEnv.createAtChat(tester);

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(chatInput, findsOneWidget);
      expect(chatSendButton, findsOneWidget);
    });

    testWidgets('Chat shows empty state when no messages', (tester) async {
      env = await TestEnv.createAtChat(tester);

      // Empty state icon visible
      expect(find.byIcon(Icons.health_and_safety), findsWidgets);
    });

    testWidgets('Chat shows quota indicator', (tester) async {
      env = await TestEnv.createAtChat(tester);

      // Should show remaining quota
      expect(find.textContaining('5'), findsWidgets);
    });

    testWidgets('Chat shows vitals bar header', (tester) async {
      env = await TestEnv.createAtChat(tester);

      // Vitals bar shows BP chip
      expect(find.textContaining('BP'), findsWidgets);
    });

    testWidgets('Send message calls API and shows response', (tester) async {
      env = await TestEnv.createAtChat(tester);

      // Type a message
      await tester.enterText(chatInput, 'How is my BP?');
      await pumpN(tester, frames: 3);

      // Tap send
      await tester.tap(chatSendButton);
      await pumpN(tester, frames: 20);

      // Verify API was called
      expect(env.tracker.hasCalled('POST', '/chat/send'), isTrue);

      // AI response should appear
      expect(find.textContaining('blood pressure'), findsOneWidget);
    });

    testWidgets('User message appears in chat after sending', (tester) async {
      env = await TestEnv.createAtChat(tester);

      await tester.enterText(chatInput, 'What should I eat?');
      await pumpN(tester, frames: 3);

      await tester.tap(chatSendButton);
      await pumpN(tester, frames: 10);

      // User's message should be visible
      expect(find.textContaining('What should I eat?'), findsOneWidget);
    });

    testWidgets('Empty message does not send', (tester) async {
      env = await TestEnv.createAtChat(tester);

      // Don't type anything, tap send
      await tester.tap(chatSendButton);
      await pumpN(tester, frames: 5);

      // No API call should be made
      expect(env.tracker.hasCalled('POST', '/chat/send'), isFalse);
    });

    testWidgets('Chat loads messages from API on init', (tester) async {
      env = await TestEnv.createAtChat(tester);

      // Verify messages endpoint was called
      expect(env.tracker.hasCalled('GET', '/chat/messages'), isTrue);
    });
  });
}
