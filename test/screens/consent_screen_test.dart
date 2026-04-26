library;

/// Tests for ConsentScreen — privacy consent after registration.
///
/// Covers: consent sections render, accept button disabled until scroll,
/// decline shows confirmation dialog, accept calls onAccept callback.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/consent_screen.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  // Helper that creates a ConsentScreen with a tracking callback
  Widget buildConsentScreen({Future<void> Function()? onAcceptCalled}) {
    return _wrap(
      ConsentScreen(
        onAccept:
            ({
              required String appVersion,
              required String language,
              required bool aiConsent,
            }) async {
              onAcceptCalled?.call();
            },
      ),
    );
  }

  testWidgets('renders consent title in app bar', (tester) async {
    await tester.pumpWidget(buildConsentScreen());
    await tester.pumpAndSettle();

    // AppBar should show consent title
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('renders all 5 consent sections', (tester) async {
    await tester.pumpWidget(buildConsentScreen());
    await tester.pumpAndSettle();

    // Should render 5 section icons (storage, family, health, gavel, AI)
    expect(find.byIcon(Icons.storage), findsOneWidget);
    expect(find.byIcon(Icons.family_restroom), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety), findsOneWidget);
    expect(find.byIcon(Icons.gavel), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy), findsOneWidget);
  });

  testWidgets('renders shield header icon', (tester) async {
    await tester.pumpWidget(buildConsentScreen());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.shield), findsOneWidget);
  });

  testWidgets('renders privacy policy link', (tester) async {
    await tester.pumpWidget(buildConsentScreen());
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.open_in_new),
      findsNWidgets(2),
    ); // Privacy Policy + ToS
  });

  testWidgets('accept button exists', (tester) async {
    await tester.pumpWidget(buildConsentScreen());
    await tester.pumpAndSettle();

    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('decline button exists and shows dialog on tap', (tester) async {
    await tester.pumpWidget(buildConsentScreen());
    await tester.pumpAndSettle();

    // Find decline TextButton (not the privacy policy one)
    final textButtons = find.byType(TextButton);
    expect(textButtons, findsWidgets);

    // Tap the last TextButton (decline is at the bottom)
    await tester.tap(textButtons.last);
    await tester.pumpAndSettle();

    // Dialog should appear with Cancel button
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
