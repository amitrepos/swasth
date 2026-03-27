class GlucoseReading {
  final int sequenceNumber;
  final DateTime timestamp;
  final double mgdl;
  final double mmol;
  final String flag;
  final String sampleType;
  final String sampleLocation;

  GlucoseReading({
    required this.sequenceNumber,
    required this.timestamp,
    required this.mgdl,
    required this.mmol,
    required this.flag,
    required this.sampleType,
    required this.sampleLocation,
  });

  @override
  String toString() {
    return 'GlucoseReading(seq: $sequenceNumber, '
        'mgdl: ${mgdl.toStringAsFixed(1)}, '
        'mmol: ${mmol.toStringAsFixed(2)}, '
        'flag: $flag, '
        'time: $timestamp)';
  }
}