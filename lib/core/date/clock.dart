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
}
