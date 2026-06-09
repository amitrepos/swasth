import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/widgets/medication_photo_thumbnail.dart';

void main() {
  testWidgets('shows loading indicator when loading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MedicationPhotoThumbnail(hasPhoto: true, loading: true),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders image bytes when provided', (tester) async {
    final bytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MedicationPhotoThumbnail(
            hasPhoto: true,
            bytes: bytes,
            size: 48,
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('shows fallback icon when photo missing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MedicationPhotoThumbnail(hasPhoto: false)),
      ),
    );
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
  });

  testWidgets('exposes semantics label when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MedicationPhotoThumbnail(
            hasPhoto: false,
            semanticsLabel: 'Add medicine package photo',
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Add medicine package photo'), findsOneWidget);
  });
}
