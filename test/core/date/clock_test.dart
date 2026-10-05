import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/date/clock.dart';

void main() {
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
