class DateTimeUtils {
  static DateTime parseUtc(dynamic val) {
    if (val == null) return DateTime.now();
    final s = val.toString();
    // If no timezone suffix, assume UTC and convert to local device time.
    // The '-' check starts at index 10 to skip the date separator.
    if (!s.endsWith('Z') && !s.contains('+') && !s.contains('-', 10)) {
      return DateTime.parse('${s}Z').toLocal();
    }
    return DateTime.parse(s).toLocal();
  }
}
