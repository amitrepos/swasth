import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/health_reading_service.dart';
import 'package:swasth_app/widgets/insights/steps_chart_card.dart';

Widget _harness(Widget child, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
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

DateTime _todayUtc() {
  final n = DateTime.now().toUtc();
  return DateTime.utc(n.year, n.month, n.day);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('hi', null);
  });

  testWidgets('x-axis shows both weekday and date labels (en)', (tester) async {
    final today = _todayUtc();
    await tester.pumpWidget(
      _harness(StepsChartCard(readings: [_steps(today.add(const Duration(hours: 12)), 5000)])),
    );
    await tester.pump();

    expect(find.text(DateFormat('E', 'en').format(today)), findsWidgets);
    expect(find.text(DateFormat('d MMM', 'en').format(today)), findsWidgets);
  });

  testWidgets('date label renders at >= 11sp for elderly legibility', (tester) async {
    final today = _todayUtc();
    await tester.pumpWidget(
      _harness(StepsChartCard(readings: [_steps(today.add(const Duration(hours: 12)), 5000)])),
    );
    await tester.pump();

    final dateText = tester.widget<Text>(
      find.text(DateFormat('d MMM', 'en').format(today)).first,
    );
    expect(dateText.style!.fontSize! >= 11, isTrue);
  });

  testWidgets('x-axis weekday renders in Devanagari when locale is hi', (tester) async {
    final today = _todayUtc();
    await tester.pumpWidget(
      _harness(
        StepsChartCard(readings: [_steps(today.add(const Duration(hours: 12)), 5000)]),
        locale: const Locale('hi'),
      ),
    );
    await tester.pump();

    final hiWeekday = DateFormat('E', 'hi').format(today);
    expect(hiWeekday, isNot(DateFormat('E', 'en').format(today)));
    expect(find.text(hiWeekday), findsWidgets,
        reason: 'Hindi locale must render weekday in Devanagari script');
  });

  // ── UTC day-bucketing (mirrors backend get_daily_steps) ──────────────────
  group('UTC day-bucketing', () {
    test('IST-midnight reading (18:30 UTC) buckets to UTC today, not next day', () {
      final today = _todayUtc();
      final istMidnight = today.add(const Duration(hours: 18, minutes: 30));

      final steps = debugDailySteps([_steps(istMidnight, 5000)], 7);

      expect(steps[6], 5000, reason: 'must bucket to today (UTC), index days-1');
      expect(steps.where((s) => s > 0).length, 1);
    });

    test('reading 6 days ago is included in the oldest bucket (index 0)', () {
      final today = _todayUtc();
      final sixDaysAgo = today.subtract(const Duration(days: 6));

      final steps = debugDailySteps(
        [_steps(sixDaysAgo.add(const Duration(hours: 12)), 4200)],
        7,
      );

      expect(steps[0], 4200);
      expect(steps.where((s) => s > 0).length, 1);
    });

    test('reading 8 days old is excluded from the 7-day window', () {
      final today = _todayUtc();
      final eightDaysAgo = today.subtract(const Duration(days: 8));

      final steps = debugDailySteps(
        [_steps(eightDaysAgo.add(const Duration(hours: 12)), 5000)],
        7,
      );

      expect(steps.every((s) => s == 0), isTrue);
    });
  });
}
