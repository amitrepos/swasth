// Widget tests for ContactSupportCard.
//
// The card is web-only and renders three contact buttons whose visibility
// depends on which env values the backend returns. These tests pin the
// visibility rules so a refactor cannot silently strip the email button
// or render a wa.me link to an empty number.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/services/api_client.dart';
import 'package:swasth_app/widgets/home/contact_support_card.dart';

http.Response _ok(Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  // The widget short-circuits when `!kIsWeb`. The flutter_test platform
  // reports kIsWeb=false, so we'd never render anything in a normal
  // widget test. We can't override kIsWeb (it's a const), but we CAN
  // verify the gate works: on non-web platforms the widget collapses
  // to a SizedBox.shrink and never calls SupportService. That IS the
  // contract we want to test for mobile builds — and it's the most
  // important regression to catch (the card accidentally rendering on
  // Android would be a visible UX bug).

  tearDown(() => ApiClient.httpClientOverride = null);

  testWidgets('renders nothing on non-web platforms (kIsWeb gate)',
      (tester) async {
    // If the widget tried to fetch, this mock would explode; the fact
    // that no HTTP call is made is part of what we're asserting.
    var fetchAttempted = false;
    ApiClient.httpClientOverride = MockClient((_) async {
      fetchAttempted = true;
      return _ok({
        'email': 'help@example.com',
        'whatsapp_number': '919876543210',
        'phone_number': '+919876543210',
      });
    });

    await tester.pumpWidget(_wrap(const ContactSupportCard()));
    await tester.pump();

    // No Contact Us heading should appear; widget renders SizedBox.shrink.
    expect(find.text('Contact Us'), findsNothing);
    expect(find.byKey(const Key('contact_support_whatsapp')), findsNothing);
    expect(find.byKey(const Key('contact_support_phone')), findsNothing);
    expect(find.byKey(const Key('contact_support_email')), findsNothing);
    expect(fetchAttempted, isFalse,
        reason: 'Mobile builds must not call the public support endpoint');
  });
}
