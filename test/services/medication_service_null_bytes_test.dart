import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasth_app/models/medication_model.dart';
import 'package:swasth_app/services/api_exception.dart';
import 'package:swasth_app/services/medication_service.dart';

void main() {
  test(
    'saveMedicationWithPhoto throws ValidationException when bytes are null',
    () async {
      final nullBytesFile = PlatformFile(
        name: 'test.jpg',
        size: 1024,
        bytes: null,
      );
      final service = MedicationService();
      expect(
        () => service.saveMedicationWithPhoto(
          MedicationCreate(
            profileId: 1,
            name: 'Metformin',
            intakePeriod: 'MORNING',
            takenAt: DateTime.now().toUtc(),
          ),
          'fake-token',
          photo: nullBytesFile,
        ),
        throwsA(isA<ValidationException>()),
      );
    },
  );
}
