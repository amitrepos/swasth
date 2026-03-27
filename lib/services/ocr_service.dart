import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String readingType; // 'glucose' or 'blood_pressure'
  final double? glucoseValue;
  final double? systolic;
  final double? diastolic;
  final double? pulse;
  final String rawText;
  final bool isHiLo; // true if glucometer returned HI or LO

  const OcrResult({
    required this.readingType,
    this.glucoseValue,
    this.systolic,
    this.diastolic,
    this.pulse,
    required this.rawText,
    this.isHiLo = false,
  });

  bool get hasValue {
    if (readingType == 'glucose') return glucoseValue != null;
    return systolic != null && diastolic != null;
  }
}

class OcrService {
  static final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract a glucose reading from a glucometer photo.
  /// Returns null if no valid value could be parsed.
  static Future<OcrResult?> extractGlucose(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);
    final rawText = recognized.text;

    if (rawText.isEmpty) return null;

    // Check for HI / LO special values
    final upperText = rawText.toUpperCase();
    if (upperText.contains(RegExp(r'\bHI\b'))) {
      return OcrResult(
        readingType: 'glucose',
        glucoseValue: 600,
        rawText: rawText,
        isHiLo: true,
      );
    }
    if (upperText.contains(RegExp(r'\bLO\b'))) {
      return OcrResult(
        readingType: 'glucose',
        glucoseValue: 20,
        rawText: rawText,
        isHiLo: true,
      );
    }

    // Find all 2-3 digit numbers in the text
    final matches = RegExp(r'\b(\d{2,3})\b').allMatches(rawText);
    for (final match in matches) {
      final value = double.tryParse(match.group(1)!);
      if (value != null && value >= 20 && value <= 600) {
        return OcrResult(
          readingType: 'glucose',
          glucoseValue: value,
          rawText: rawText,
        );
      }
    }

    return OcrResult(readingType: 'glucose', rawText: rawText);
  }

  /// Extract systolic, diastolic, and pulse from a BP monitor photo.
  /// Returns null if no valid values could be parsed.
  static Future<OcrResult?> extractBloodPressure(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);
    final rawText = recognized.text;

    if (rawText.isEmpty) return null;

    // Primary pattern: systolic/diastolic (e.g. "128/82" or "128 / 82")
    final bpMatch = RegExp(r'(\d{2,3})\s*/\s*(\d{2,3})').firstMatch(rawText);
    if (bpMatch != null) {
      final systolic = double.tryParse(bpMatch.group(1)!);
      final diastolic = double.tryParse(bpMatch.group(2)!);

      if (systolic != null && diastolic != null &&
          systolic >= 60 && systolic <= 250 &&
          diastolic >= 40 && diastolic <= 150) {
        // Try to find pulse: a 2-3 digit number NOT already used as systolic/diastolic
        double? pulse;
        final usedValues = {systolic.toInt(), diastolic.toInt()};
        final allNumbers = RegExp(r'\b(\d{2,3})\b').allMatches(rawText);
        for (final m in allNumbers) {
          final v = double.tryParse(m.group(1)!);
          if (v != null && !usedValues.contains(v.toInt()) &&
              v >= 30 && v <= 200) {
            pulse = v;
            break;
          }
        }

        return OcrResult(
          readingType: 'blood_pressure',
          systolic: systolic,
          diastolic: diastolic,
          pulse: pulse,
          rawText: rawText,
        );
      }
    }

    return OcrResult(readingType: 'blood_pressure', rawText: rawText);
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
