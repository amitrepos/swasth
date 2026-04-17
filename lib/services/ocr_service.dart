import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String readingType; // 'glucose' or 'blood_pressure'
  final double? glucoseValue;
  final double? systolic;
  final double? diastolic;
  final double? pulse;
  final double? weightValue;
  final String rawText;
  final bool isHiLo; // true if glucometer returned HI or LO

  const OcrResult({
    required this.readingType,
    this.glucoseValue,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.weightValue,
    required this.rawText,
    this.isHiLo = false,
  });

  bool get hasValue {
    if (readingType == 'glucose') return glucoseValue != null;
    if (readingType == 'weight') return weightValue != null;
    return systolic != null && diastolic != null;
  }
}

class OcrService {
  static final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract a glucose reading from a glucometer photo.
  static Future<OcrResult?> extractGlucose(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);
    final rawText = recognized.text;

    if (rawText.isEmpty) return null;

    final upperText = rawText.toUpperCase();
    if (upperText.contains(RegExp(r'\bHI\b'))) {
      return OcrResult(readingType: 'glucose', glucoseValue: 600, rawText: rawText, isHiLo: true);
    }
    if (upperText.contains(RegExp(r'\bLO\b'))) {
      return OcrResult(readingType: 'glucose', glucoseValue: 20, rawText: rawText, isHiLo: true);
    }

    final matches = RegExp(r'\b(\d{2,3})\b').allMatches(rawText);
    for (final match in matches) {
      final value = double.tryParse(match.group(1)!);
      if (value != null && value >= 20 && value <= 600) {
        return OcrResult(readingType: 'glucose', glucoseValue: value, rawText: rawText);
      }
    }

    return OcrResult(readingType: 'glucose', rawText: rawText);
  }

  /// Extract systolic, diastolic, and pulse from a BP monitor photo.
  ///
  /// Tries multiple patterns because different BP monitors format readings
  /// differently:
  ///   - Pattern 1: "128/82"  (slash format — some monitors)
  ///   - Pattern 2: Two numbers on separate lines (most Omron/Yuwell/A&D monitors)
  ///   - Pattern 3: Numbers near SYS/DIA labels
  ///   - Pattern 4: Pick the two most plausible numbers from all detected numbers
  static Future<OcrResult?> extractBloodPressure(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);
    final rawText = recognized.text;

    if (rawText.isEmpty) return null;

    // ── Pattern 1: "128/82" or "128 / 82" (slash separator) ─────────────────
    final slashMatch = RegExp(r'(\d{2,3})\s*/\s*(\d{2,3})').firstMatch(rawText);
    if (slashMatch != null) {
      final sys = double.tryParse(slashMatch.group(1)!);
      final dia = double.tryParse(slashMatch.group(2)!);
      if (_validBP(sys, dia)) {
        return OcrResult(
          readingType: 'blood_pressure',
          systolic: sys,
          diastolic: dia,
          pulse: _extractPulse(rawText, sys!, dia!),
          rawText: rawText,
        );
      }
    }

    // ── Pattern 2: SYS / DIA label-adjacent numbers ──────────────────────────
    // Many monitors print "SYS 128  DIA 82" or "SYS\n128\nDIA\n82"
    final upperText = rawText.toUpperCase();
    final sysLabelMatch = RegExp(r'SYS[^\d]{0,6}(\d{2,3})').firstMatch(upperText);
    final diaLabelMatch = RegExp(r'DIA[^\d]{0,6}(\d{2,3})').firstMatch(upperText);
    if (sysLabelMatch != null && diaLabelMatch != null) {
      final sys = double.tryParse(sysLabelMatch.group(1)!);
      final dia = double.tryParse(diaLabelMatch.group(1)!);
      if (_validBP(sys, dia)) {
        return OcrResult(
          readingType: 'blood_pressure',
          systolic: sys,
          diastolic: dia,
          pulse: _extractPulse(rawText, sys!, dia!),
          rawText: rawText,
        );
      }
    }

    // ── Pattern 3: Two numbers on separate lines ──────────────────────────────
    // Most digital BP monitors show systolic on one line, diastolic on the next.
    // e.g. Omron HEM-7140T:
    //   128
    //    82
    //   ♥ 72
    final lines = rawText.split(RegExp(r'[\n\r]+')).map((l) => l.trim()).toList();
    final lineNumbers = <double>[];
    for (final line in lines) {
      final m = RegExp(r'\b(\d{2,3})\b').firstMatch(line);
      if (m != null) {
        final v = double.tryParse(m.group(1)!);
        if (v != null) lineNumbers.add(v);
      }
    }

    // Slide a window of 2 over line-numbers looking for a valid sys+dia pair
    for (int i = 0; i < lineNumbers.length - 1; i++) {
      final a = lineNumbers[i];
      final b = lineNumbers[i + 1];
      if (_validBP(a, b)) {
        return OcrResult(
          readingType: 'blood_pressure',
          systolic: a,
          diastolic: b,
          pulse: _extractPulse(rawText, a, b),
          rawText: rawText,
        );
      }
    }

    // ── Pattern 4: All numbers — pick best systolic + diastolic candidate ────
    // Last resort: collect every 2-3 digit number and try all pairs
    final allNums = RegExp(r'\b(\d{2,3})\b')
        .allMatches(rawText)
        .map((m) => double.tryParse(m.group(1)!))
        .whereType<double>()
        .toList();

    final sysCandidates = allNums.where((v) => v >= 90 && v <= 200).toList();
    final diaCandidates = allNums.where((v) => v >= 50 && v <= 130).toList();

    for (final sys in sysCandidates) {
      for (final dia in diaCandidates) {
        if (sys != dia && sys > dia && _validBP(sys, dia)) {
          return OcrResult(
            readingType: 'blood_pressure',
            systolic: sys,
            diastolic: dia,
            pulse: _extractPulse(rawText, sys, dia),
            rawText: rawText,
          );
        }
      }
    }

    // Nothing matched — return empty result so caller can show "try again"
    return OcrResult(readingType: 'blood_pressure', rawText: rawText);
  }

  /// Returns true when systolic and diastolic are physiologically plausible.
  static bool _validBP(double? sys, double? dia) {
    if (sys == null || dia == null) return false;
    return sys >= 70 && sys <= 250 &&
        dia >= 40 && dia <= 150 &&
        sys > dia;
  }

  /// Finds a plausible pulse value from the raw text, excluding already-used numbers.
  static double? _extractPulse(String rawText, double sys, double dia) {
    final usedInts = {sys.toInt(), dia.toInt()};
    // Check for pulse/heart-rate label first
    final pulseLabel = RegExp(r'(?:PULSE|HEART|♥|HR)[^\d]{0,6}(\d{2,3})', caseSensitive: false)
        .firstMatch(rawText);
    if (pulseLabel != null) {
      final v = double.tryParse(pulseLabel.group(1)!);
      if (v != null && v >= 30 && v <= 200) return v;
    }
    // Fall back: first 2-3 digit number in valid pulse range not already used
    for (final m in RegExp(r'\b(\d{2,3})\b').allMatches(rawText)) {
      final v = double.tryParse(m.group(1)!);
      if (v != null && !usedInts.contains(v.toInt()) && v >= 30 && v <= 200) return v;
    }
    return null;
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
