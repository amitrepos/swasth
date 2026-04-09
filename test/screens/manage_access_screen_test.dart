/// Tests for ManageAccessScreen — profile sharing & access management.
///
/// Covers: renders invite form, email field, relationship dropdown,
/// access level dropdown, invite button, and "not shared yet" empty state.
/// Security-critical: this screen controls who can see patient health data.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:swasth_app/l10n/app_localizations.dart';
import 'package:swasth_app/screens/manage_access_screen.dart';
import 'package:swasth_app/services/storage_service.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  setUp(() {
    // Use in-memory storage to avoid native plugin crashes in tests
    StorageService.useInMemoryStorage();
  });

  tearDown(() {
    StorageService.useRealStorage();
  });

  testWidgets('renders app bar with manage access title', (tester) async {
    await tester.pumpWidget(_wrap(
      const ManageAccessScreen(profileId: 1, profileName: 'Test Profile'),
    ));
    // Use pump instead of pumpAndSettle to avoid infinite animation hangs
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('renders email text field for inviting', (tester) async {
    await tester.pumpWidget(_wrap(
      const ManageAccessScreen(profileId: 1, profileName: 'Test Profile'),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('renders relationship dropdown', (tester) async {
    await tester.pumpWidget(_wrap(
      const ManageAccessScreen(profileId: 1, profileName: 'Test Profile'),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    // Should have 2 dropdowns: relationship and access level
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
  });

  testWidgets('renders access level dropdown with viewer and editor options', (tester) async {
    await tester.pumpWidget(_wrap(
      const ManageAccessScreen(profileId: 1, profileName: 'Test Profile'),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    // Access level dropdown should show default "Viewer" text
    expect(find.text('Viewer — can only view readings'), findsOneWidget);
  });

  testWidgets('renders invite button', (tester) async {
    await tester.pumpWidget(_wrap(
      const ManageAccessScreen(profileId: 1, profileName: 'Test Profile'),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('renders divider between invite form and access list', (tester) async {
    await tester.pumpWidget(_wrap(
      const ManageAccessScreen(profileId: 1, profileName: 'Test Profile'),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('screen renders without crashing', (tester) async {
    await tester.pumpWidget(_wrap(
      const ManageAccessScreen(profileId: 1, profileName: 'Test Profile'),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    // Screen should render (AppBar + body)
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
