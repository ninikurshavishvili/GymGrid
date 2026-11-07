import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/date/clock.dart';

void main() {
  group('untilTomorrow', () {
    Duration until(DateTime now) => Clock(() => now).untilTomorrow();

    test('counts down to the next local midnight', () {
      expect(
        until(DateTime(2026, 11, 6, 23, 59, 30)),
        const Duration(seconds: 30),
      );
      expect(until(DateTime(2026, 11, 6, 12)), const Duration(hours: 12));
    });

    test('a whole day remains at midnight itself', () {
      expect(until(DateTime(2026, 11, 6)), const Duration(hours: 24));
    });

    test('crosses month and year ends', () {
      expect(until(DateTime(2026, 2, 28, 23)), const Duration(hours: 1));
      expect(until(DateTime(2026, 12, 31, 23)), const Duration(hours: 1));
    });
  });

  test('today is the calendar day of now', () {
    final clock = Clock(() => DateTime(2026, 10, 5, 23, 59));

    expect(clock.today(), CalendarDay(2026, 10, 5));
  });

  test('reads the device time by default', () {
    final before = DateTime.now();
    final now = const Clock().now();
    final after = DateTime.now();

    expect(now.isBefore(before), isFalse);
    expect(now.isAfter(after), isFalse);
  });
}
