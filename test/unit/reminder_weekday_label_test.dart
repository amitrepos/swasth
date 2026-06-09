import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/widgets/reminder_settings_sheet.dart';

void main() {
  testWidgets('weekday labels are non-empty for days 0–6 in all locales', (
    tester,
  ) async {
    for (final locale in const [
      Locale('en'),
      Locale('hi'),
      Locale('kn'),
      Locale('ta'),
      Locale('te'),
    ]) {
      for (var day = 0; day <= 6; day++) {
        late String label;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                label = reminderWeekdayLabel(context, day);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(
          label.trim().isNotEmpty,
          isTrue,
          reason: '${locale.toString()} day=$day',
        );
      }
    }
  });
}
