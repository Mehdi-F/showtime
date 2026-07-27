/// Calculate number of days between today and a target date.
///
/// Returns:
/// - 0 if today
/// - negative if in the past
/// - positive if in the future
int daysUntil(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays;
}

/// Safely parse a DateTime string, returning null if parsing fails.
///
/// Used to handle malformed dates from external APIs (TMDB).
DateTime? tryParseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is! String) return null;
  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}

/// Represents time spent watching in years, months, days, and hours.
class WatchTime {
  final int months;
  final int days;
  final int hours;

  /// Creates a WatchTime from total minutes watched.
  WatchTime(int totalMinutes)
      : hours = (totalMinutes ~/ 60) % 24,
        days = (totalMinutes ~/ (60 * 24)) % 30,
        months = totalMinutes ~/ (60 * 24 * 30);

  @override
  String toString() => '$months mois, $days jours, $hours heures';
}
