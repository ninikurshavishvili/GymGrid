import 'calendar_day.dart';

/// Tells the time. Injected wherever code needs "now" or "today", so tests
/// can fix the time instead of depending on when they run; the Swift
/// equivalent is injecting a `() -> Date` rather than calling `Date()`.
class Clock {
  /// A clock that reads the device time, or calls [now] if given.
  const Clock([this._now = DateTime.now]);

  final DateTime Function() _now;

  /// The current local date and time.
  DateTime now() => _now();

  /// The current local calendar day.
  CalendarDay today() => CalendarDay.fromDateTime(now());

  /// How long until the next local midnight.
  ///
  /// Built from the date rather than by adding 24 hours, so it's right on a
  /// day that daylight saving makes 23 or 25 hours long.
  Duration untilTomorrow() {
    final current = now();
    return DateTime(
      current.year,
      current.month,
      current.day + 1,
    ).difference(current);
  }
}
