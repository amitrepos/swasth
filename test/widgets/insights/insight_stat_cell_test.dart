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
}
