import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/services/storage_service.dart';
import 'package:swasth_app/widgets/insights/insight_stat_cell.dart';

import '../../helpers/test_app.dart';

void main() {
  group('TrendChartScreen stat zoom', () {
    late TestEnv env;

    tearDown(() => env.dispose());

    testWidgets('Zoom button cycles through 3 scales and wraps', (
      tester,
    ) async {
      env = await TestEnv.createAtInsights(tester);

      final zoomBtn = find.byKey(const Key('insights_stat_zoom'));
      expect(zoomBtn, findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);

      await tester.tap(zoomBtn);
      await pumpN(tester, frames: 5);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);

      await tester.tap(zoomBtn);
      await pumpN(tester, frames: 5);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);

      await tester.tap(zoomBtn);
      await pumpN(tester, frames: 5);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    });

    testWidgets('Zoom tap enlarges stat value font then resets', (
      tester,
    ) async {
      env = await TestEnv.createAtInsights(tester);

      final avgTexts = find.descendant(
        of: find.byType(InsightStatCell),
        matching: find.byType(Text),
      );
      expect(avgTexts, findsWidgets);

      final baseFont = tester
          .widgetList<Text>(avgTexts)
          .firstWhere((t) => t.style?.fontWeight == FontWeight.w700)
          .style!
          .fontSize!;

      await tester.tap(find.byKey(const Key('insights_stat_zoom')));
      await pumpN(tester, frames: 5);

      final enlargedFont = tester
          .widgetList<Text>(avgTexts)
          .firstWhere((t) => t.style?.fontWeight == FontWeight.w700)
          .style!
          .fontSize!;
      expect(enlargedFont, greaterThan(baseFont));

      await tester.tap(find.byKey(const Key('insights_stat_zoom')));
      await pumpN(tester, frames: 5);
      await tester.tap(find.byKey(const Key('insights_stat_zoom')));
      await pumpN(tester, frames: 5);

      final resetFont = tester
          .widgetList<Text>(avgTexts)
          .firstWhere((t) => t.style?.fontWeight == FontWeight.w700)
          .style!
          .fontSize!;
      expect(resetFont, closeTo(baseFont, 0.1));
    });

    testWidgets('Loads persisted stat scale from storage', (tester) async {
      StorageService.useInMemoryStorage();
      await StorageService().saveToken('mock_token_123');
      await StorageService().saveInsightsStatScale(1.35);

      env = await TestEnv.createAtInsights(tester);

      final valueTexts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(InsightStatCell),
          matching: find.byType(Text),
        ),
      );
      final valueFont = valueTexts
          .firstWhere((t) => t.style?.fontWeight == FontWeight.w700)
          .style!
          .fontSize!;
      expect(valueFont, closeTo(18 * 1.35, 0.1));
    });
  });
}
