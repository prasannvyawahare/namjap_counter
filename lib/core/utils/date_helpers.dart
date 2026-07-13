import 'package:intl/intl.dart';

/// Date utilities used across storage and statistics. All records are keyed by
/// a `yyyy-MM-dd` string so that a new calendar day naturally starts a fresh
/// record (this is what powers the automatic midnight reset).
class DateHelpers {
  const DateHelpers._();

  static final DateFormat _keyFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _shortFormat = DateFormat('d MMM');
  static final DateFormat _longFormat = DateFormat('EEEE, MMMM d, y');
  static final DateFormat _monthFormat = DateFormat('MMMM y');
  static final DateFormat _monthShort = DateFormat('MMM y');

  static String key(DateTime date) => _keyFormat.format(_dateOnly(date));

  static DateTime? parseKey(String key) {
    try {
      return _keyFormat.parseStrict(key);
    } catch (_) {
      return null;
    }
  }

  static String shortLabel(DateTime date) => _shortFormat.format(date);

  static String longLabel(DateTime date) => _longFormat.format(date);

  static String monthLabel(DateTime date) => _monthFormat.format(date);

  static String monthShortLabel(DateTime date) => _monthShort.format(date);

  static String greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Monday as the first day of the week.
  static DateTime startOfWeek(DateTime date) {
    final d = _dateOnly(date);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static DateTime endOfWeek(DateTime date) =>
      startOfWeek(date).add(const Duration(days: 6));

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime startOfYear(DateTime date) => DateTime(date.year, 1, 1);

  static bool isInWeek(DateTime date, DateTime reference) {
    final start = startOfWeek(reference);
    final end = endOfWeek(reference);
    final d = _dateOnly(date);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  static bool isInMonth(DateTime date, DateTime reference) =>
      date.year == reference.year && date.month == reference.month;

  static bool isInYear(DateTime date, DateTime reference) =>
      date.year == reference.year;
}
