import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/health_reading_service.dart';
import 'package:swasth_app/widgets/insights/pulse_chart_card.dart';

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

HealthReading _bp(DateTime tsUtc, int pulse) => HealthReading(
      id: tsUtc.millisecondsSinceEpoch,
      profileId: 1,
      readingType: 'blood_pressure',
      systolic: 122,
      diastolic: 80,
      pulseRate: pulse.toDouble(),
      bpUnit: 'mmHg',
      valueNumeric: 122,
      unitDisplay: 'mmHg',
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
      _harness(PulseChartCard(readings: [_bp(today.add(const Duration(hours: 12)), 74)])),
    );
    await tester.pump();

    expect(find.text(DateFormat('E', 'en').format(today)), findsWidgets);
    expect(find.text(DateFormat('d MMM', 'en').format(today)), findsWidgets);
  });

  testWidgets('date label renders at >= 11sp for elderly legibility', (tester) async {
    final today = _todayUtc();
    await tester.pumpWidget(
      _harness(PulseChartCard(readings: [_bp(today.add(const Duration(hours: 12)), 74)])),
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
        PulseChartCard(readings: [_bp(today.add(const Duration(hours: 12)), 74)]),
        locale: const Locale('hi'),
      ),
    );
    await tester.pump();

    final hiWeekday = DateFormat('E', 'hi').format(today);
    // Guard against the test tautologically matching the en label.
    expect(hiWeekday, isNot(DateFormat('E', 'en').format(today)));
    expect(find.text(hiWeekday), findsWidgets,
        reason: 'Hindi locale must render weekday in Devanagari script');
  });

  // ── UTC day-bucketing (health-critical) ──────────────────────────────────
  group('UTC day-bucketing', () {
    test('IST-midnight reading (18:30 UTC) buckets to UTC today, not next day', () {
      // 18:30 UTC = 00:00 IST(+5:30). Under the old .toLocal() bucketing this
      // would land on "tomorrow" (out of the 7-day window) and disappear.
      final today = _todayUtc();
      final istMidnight = today.add(const Duration(hours: 18, minutes: 30));

      final avgs = debugDailyPulseAverages([_bp(istMidnight, 74)], 7);

      expect(avgs[6], isNotNull, reason: 'must bucket to today (UTC), index days-1');
      expect(avgs[6], closeTo(74, 0.001));
      expect(avgs.where((e) => e != null).length, 1);
    });

    test('reading 6 days ago is included in the oldest bucket (index 0)', () {
      final today = _todayUtc();
      final sixDaysAgo = today.subtract(const Duration(days: 6));

      final avgs = debugDailyPulseAverages(
        [_bp(sixDaysAgo.add(const Duration(hours: 12)), 80)],
        7,
      );

      expect(avgs[0], closeTo(80, 0.001));
      expect(avgs.where((e) => e != null).length, 1);
    });

    test('reading 8 days old is excluded from the 7-day window', () {
      final today = _todayUtc();
      final eightDaysAgo = today.subtract(const Duration(days: 8));

      final avgs = debugDailyPulseAverages(
        [_bp(eightDaysAgo.add(const Duration(hours: 12)), 74)],
        7,
      );

      expect(avgs.every((e) => e == null), isTrue);
    });
  });
}
