import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/health_reading_service.dart';
import 'package:swasth_app/widgets/insights/steps_chart_card.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('hi')],
    home: Scaffold(body: SizedBox(width: 400, child: child)),
  );
}

HealthReading _steps(DateTime tsUtc, int count) => HealthReading(
      id: tsUtc.millisecondsSinceEpoch,
      profileId: 1,
      readingType: 'steps',
      stepsCount: count,
      valueNumeric: count.toDouble(),
      unitDisplay: 'steps',
      readingTimestamp: tsUtc,
      createdAt: tsUtc,
    );

void main() {
  testWidgets('x-axis shows both weekday and date labels (en)', (tester) async {
    // Mirror the widget's UTC day-bucketing so the expected label is exact.
    final nowUtc = DateTime.now().toUtc();
    final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

    await tester.pumpWidget(
      _harness(StepsChartCard(readings: [_steps(today.add(const Duration(hours: 12)), 5000)])),
    );
    await tester.pump();

    final weekday = DateFormat('E', 'en').format(today);
    final date = DateFormat('d MMM', 'en').format(today);

    expect(find.text(weekday), findsWidgets);
    expect(find.text(date), findsWidgets);
  });

  testWidgets('date label renders at >= 11sp for elderly legibility', (tester) async {
    final nowUtc = DateTime.now().toUtc();
    final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

    await tester.pumpWidget(
      _harness(StepsChartCard(readings: [_steps(today.add(const Duration(hours: 12)), 5000)])),
    );
    await tester.pump();

    final date = DateFormat('d MMM', 'en').format(today);
    final dateText = tester.widget<Text>(find.text(date).first);
    expect(dateText.style!.fontSize! >= 11, isTrue);
  });
}
