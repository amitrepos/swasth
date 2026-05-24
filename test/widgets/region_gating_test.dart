// Widget-level region gating tests (NUO-135).
//
// Mounts each gated screen with RegionService preloaded so writeAllowed=false,
// then asserts the write affordance is hidden. Mirror with writeAllowed=true
// to guard against regressions where the gate becomes permanently sticky.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/add_medication_screen.dart';
import 'package:swasth_app/screens/medications_screen.dart';
import 'package:swasth_app/screens/reading_confirmation_screen.dart';
import 'package:swasth_app/services/region_service.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/theme/app_theme.dart';
import 'package:swasth_app/widgets/non_india_banner.dart';

import '../helpers/test_app.dart' show pumpN;

const _writeBlocked = RegionInfo(
  countryCode: 'US',
  writeAllowed: false,
  source: 'ip',
);
const _writeAllowed = RegionInfo(
  countryCode: 'IN',
  writeAllowed: true,
  source: 'ip',
);

Future<void> _pumpScreen(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  StorageService.useInMemoryStorage();
  await StorageService().saveToken('test-token');

  // Suppress overflow noise in test viewport.
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed') || msg.contains('overflow')) return;
    original?.call(details);
  };

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: child,
    ),
  );
  await pumpN(tester, frames: 5);
}

void main() {
  tearDown(() => RegionService.setCacheForTest(null));

  group('NonIndiaBanner — region gating', () {
    testWidgets('shows banner copy when write blocked', (tester) async {
      RegionService.setCacheForTest(_writeBlocked);
      await _pumpScreen(tester, const Scaffold(body: NonIndiaBanner()));
      expect(find.byKey(const Key('non_india_banner')), findsOneWidget);
      expect(find.textContaining('family member'), findsOneWidget);
    });

    testWidgets('hidden when writes allowed', (tester) async {
      RegionService.setCacheForTest(_writeAllowed);
      await _pumpScreen(tester, const Scaffold(body: NonIndiaBanner()));
      expect(find.byKey(const Key('non_india_banner')), findsNothing);
    });
  });

  group('ReadingConfirmationScreen — region gating', () {
    testWidgets('Save button replaced with banner when blocked', (
      tester,
    ) async {
      RegionService.setCacheForTest(_writeBlocked);
      await _pumpScreen(
        tester,
        const ReadingConfirmationScreen(
          ocrResult: null,
          deviceType: 'glucose',
          profileId: 1,
        ),
      );
      expect(find.byKey(const Key('reading_save_button')), findsNothing);
      expect(
        find.byKey(const Key('reading_save_blocked_region')),
        findsOneWidget,
      );
    });

    testWidgets('Save button visible when writes allowed', (tester) async {
      RegionService.setCacheForTest(_writeAllowed);
      await _pumpScreen(
        tester,
        const ReadingConfirmationScreen(
          ocrResult: null,
          deviceType: 'glucose',
          profileId: 1,
        ),
      );
      expect(find.byKey(const Key('reading_save_button')), findsOneWidget);
      expect(
        find.byKey(const Key('reading_save_blocked_region')),
        findsNothing,
      );
    });
  });

  group('AddMedicationSheet — region gating', () {
    // The medications sheet itself does NOT gate region — the parent
    // MedicationsScreen hides the FAB. But once mounted the sheet must
    // still let the form render so a future deep-link cannot break it.
    testWidgets('renders form regardless of region', (tester) async {
      RegionService.setCacheForTest(_writeBlocked);
      await _pumpScreen(
        tester,
        const Scaffold(body: AddMedicationSheet(profileId: 1)),
      );
      expect(find.byKey(const Key('medication-name-field')), findsOneWidget);
    });
  });

  group('MedicationsScreen — region gating', () {
    testWidgets('FAB hidden when region writes blocked', (tester) async {
      RegionService.setCacheForTest(_writeBlocked);
      await _pumpScreen(tester, const MedicationsScreen(profileId: 1));
      // Give the GET /medications call (which will fail in test) time to settle.
      await pumpN(tester, frames: 10);
      expect(find.byKey(const Key('medications-add-fab')), findsNothing);
    });
  });
}
