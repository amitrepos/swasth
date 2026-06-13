import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/widgets/insights/insight_stat_cell.dart';

void main() {
  testWidgets('InsightStatCell scales value font size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              InsightStatCell(label: 'Avg', value: '120', scale: 1.0),
              InsightStatCell(label: 'Avg', value: '120', scale: 1.7),
            ],
          ),
        ),
      ),
    );

    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    final baseValue = texts[0].style!.fontSize!;
    final scaledValue = texts[2].style!.fontSize!;
    expect(scaledValue, greaterThan(baseValue));
    expect(baseValue, 18);
    expect(scaledValue, closeTo(30.6, 0.1));
  });

  testWidgets('InsightStatCell label stays at least 13sp', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InsightStatCell(label: 'Min', value: '90', scale: 1.0),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('Min'));
    expect(label.style!.fontSize! >= 13, isTrue);
  });

  testWidgets(
    'InsightStatCell at mid scale 1.35 renders between base and max',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InsightStatCell(label: 'Avg', value: '120', scale: 1.35),
          ),
        ),
      );

      final value = tester.widget<Text>(find.text('120'));
      expect(value.style!.fontSize!, closeTo(24.3, 0.1));
      expect(value.style!.fontSize!, lessThan(30.6));
    },
  );

  testWidgets('InsightStatCell clamps value font at max scale', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InsightStatCell(label: 'Avg', value: '120', scale: 2.0),
        ),
      ),
    );

    final value = tester.widget<Text>(find.text('120'));
    expect(value.style!.fontSize!, 32);
  });

  testWidgets('InsightStatCell clamps label font at max scale', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InsightStatCell(label: 'Avg', value: '120', scale: 2.0),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('Avg'));
    expect(label.style!.fontSize!, 16);
  });
}
