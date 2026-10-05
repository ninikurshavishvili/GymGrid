import 'package:equatable/equatable.dart';

/// A date without a time of day or time zone, such as the day of a check-in.
///
/// Dart has no date-only type (nor does Swift; `DateComponents` is the
/// nearest). A local [DateTime] at midnight is the usual stand-in, but it is
/// fragile: across a daylight saving change two local midnights are 23 or 25
/// hours apart, so adding `Duration(days: 1)` can land on the same day, and
/// subtracting them can report zero days. [CalendarDay] keeps its date as
/// midnight UTC, where every day is exactly 24 hours, so day arithmetic and
/// comparisons are exact.
class CalendarDay extends Equatable implements Comparable<CalendarDay> {
  /// Out-of-range values roll over as in [DateTime]: `CalendarDay(2026, 12,
  /// 32)` is 1 January 2027.
  CalendarDay(int year, int month, int day)
    : _midnightUtc = DateTime.utc(year, month, day);

  /// The calendar day of [dateTime] in its own time zone. Pass a local
  /// [DateTime] to get the user's day.
  CalendarDay.fromDateTime(DateTime dateTime)
    : this(dateTime.year, dateTime.month, dateTime.day);

  const CalendarDay._(this._midnightUtc);

  /// Parses `yyyy-MM-dd`, e.g. `2026-10-05`. Returns null for anything else,
  /// including dates that don't exist, such as `2026-02-30`.
  static CalendarDay? tryParse(String value) {
    final match = _isoPattern.firstMatch(value);
    if (match == null) return null;
    final day = CalendarDay(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
    // The constructor would roll 2026-02-30 over to 2 March; reject it.
    return day.toIso8601String() == value ? day : null;
  }

  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final DateTime _midnightUtc;

  int get year => _midnightUtc.year;

  int get month => _midnightUtc.month;

  int get day => _midnightUtc.day;

  /// [DateTime.monday] (1) to [DateTime.sunday] (7).
  int get weekday => _midnightUtc.weekday;

  /// The day [days] after this one, or before it if [days] is negative.
  CalendarDay addDays(int days) =>
      CalendarDay._(_midnightUtc.add(Duration(days: days)));

  /// Whole days from [other] to this day: 1 if [other] is the day before,
  /// negative if [other] is later.
  int daysSince(CalendarDay other) =>
      _midnightUtc.difference(other._midnightUtc).inDays;

  bool isBefore(CalendarDay other) => _midnightUtc.isBefore(other._midnightUtc);

  bool isAfter(CalendarDay other) => _midnightUtc.isAfter(other._midnightUtc);

  @override
  int compareTo(CalendarDay other) =>
      _midnightUtc.compareTo(other._midnightUtc);

  /// Local midnight at the start of this day, for date formatters that take
  /// a [DateTime].
  DateTime toLocalDateTime() => DateTime(year, month, day);

  /// `yyyy-MM-dd`, e.g. `2026-10-05`.
  String toIso8601String() {
    String pad(int value, int width) => value.toString().padLeft(width, '0');
    return '${pad(year, 4)}-${pad(month, 2)}-${pad(day, 2)}';
  }

  @override
  List<Object> get props => [_midnightUtc];

  @override
  String toString() => toIso8601String();
}
