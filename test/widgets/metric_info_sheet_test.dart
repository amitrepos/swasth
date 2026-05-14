import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/utils/metric_ranges.dart';
import 'package:swasth_app/widgets/home/metric_info_sheet.dart';

Widget _harness({required Widget Function(BuildContext) builder}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('hi')],
    home: Scaffold(body: Builder(builder: builder)),
  );
}

Future<void> _openSheet(WidgetTester tester, MetricInfoSpec spec) async {
  await tester.pumpWidget(
    _harness(
      builder: (ctx) => ElevatedButton(
        onPressed: () => showMetricInfoSheet(ctx, spec),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('BP sheet shows title, current reading, 4 levels, sources', (
    tester,
  ) async {
    final spec = buildBpSpec(sys: 146, dia: 96, age: 35, conditions: const []);
    await _openSheet(tester, spec);

    expect(find.byKey(const Key('metric_info_title')), findsOneWidget);
    expect(find.text('BLOOD PRESSURE'), findsOneWidget);
    expect(
      find.byKey(const Key('metric_info_current_reading')),
      findsOneWidget,
    );
    expect(find.textContaining('146/96'), findsOneWidget);
    // Reading is 146/96 → Urgent; level labels appear in level-rows.
    // 'Urgent' also appears in the current-reading card → count is 2.
    expect(find.text('Fit & Fine'), findsOneWidget);
    expect(find.text('Caution'), findsOneWidget);
    expect(find.text('At Risk'), findsOneWidget);
    expect(find.text('Urgent'), findsNWidgets(2));

    // Source chips render.
    expect(find.byKey(const Key('source_chip_IHCI')), findsOneWidget);
    expect(find.byKey(const Key('source_chip_ICMR')), findsOneWidget);
  });

  testWidgets('BP sheet with no reading shows fallback card', (tester) async {
    final spec = buildBpSpec(
      sys: null,
      dia: null,
      age: 40,
      conditions: const [],
    );
    await _openSheet(tester, spec);
    expect(find.textContaining('No reading yet'), findsOneWidget);
    expect(find.byKey(const Key('metric_info_current_reading')), findsNothing);
  });

  testWidgets('BMI sheet personalises for senior 65+', (tester) async {
    final spec = buildBmiSpec(bmi: 25, age: 70);
    await _openSheet(tester, spec);
    expect(find.textContaining('Senior 65+'), findsOneWidget);
    // 25 falls inside the protective 22–27 band for seniors.
    expect(find.textContaining('22.0–27.0 (protective)'), findsOneWidget);
  });

  testWidgets('Glucose sheet for known diabetic shows tighter target label', (
    tester,
  ) async {
    final spec = buildGlucoseSpec(
      mgdl: 145,
      age: 50,
      conditions: const ['Diabetes T2'],
    );
    await _openSheet(tester, spec);
    expect(find.textContaining('Diabetes'), findsWidgets);
    expect(find.text('Caution'), findsWidgets);
  });

  testWidgets('Steps sheet renders for sedentary user', (tester) async {
    final spec = buildStepsSpec(count: 70, age: 40, conditions: const []);
    await _openSheet(tester, spec);
    expect(find.textContaining('70 steps'), findsOneWidget);
    expect(find.textContaining('very low movement'), findsWidgets);
  });

  testWidgets('Disclaimer always present', (tester) async {
    final spec = buildBpSpec(sys: 120, dia: 80, age: 30, conditions: const []);
    await _openSheet(tester, spec);
    expect(
      find.textContaining('Not a substitute for your doctor'),
      findsOneWidget,
    );
  });
}
