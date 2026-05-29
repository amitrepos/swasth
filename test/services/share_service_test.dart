import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/share_service.dart';

import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareService.shareInvite — error path coverage (M4)', () {
    const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/share');

    testWidgets('shows SnackBar when Share.share throws', (tester) async {
      // Mock the platform channel to throw an exception
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'share') {
            throw Exception('Platform failure');
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () => ShareService.shareInvite(context),
                child: const Text('Share'),
              );
            }),
          ),
        ),
      );
      await pumpN(tester, frames: 3);

      await tester.tap(find.text('Share'));
      // Handle the async gap and animation
      await pumpN(tester, frames: 5);

      // Verify the SnackBar appeared (exact match for errGeneric in app_en.arb)
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    });

    testWidgets('returns false when Localizations is missing from context (M3)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          // No AppLocalizations delegate provided here
          home: Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  final result = await ShareService.shareInvite(context);
                  // Should return false cleanly, not crash
                  if (!result) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Handled Null')),
                    );
                  }
                },
                child: const Text('Share'),
              );
            }),
          ),
        ),
      );
      await pumpN(tester, frames: 3);

      await tester.tap(find.text('Share'));
      await pumpN(tester, frames: 3);

      // Verify it didn't crash and showed our 'Handled Null' indicator
      expect(find.text('Handled Null'), findsOneWidget);
    });
  });
}
