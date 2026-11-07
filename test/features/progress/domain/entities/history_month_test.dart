import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/progress/domain/entities/history_month.dart';

CheckIn _checkInOn(CalendarDay day) => CheckIn(
  id: '$day',
  date: day,
  photoPaths: ['photos/$day.jpg'],
  workoutType: WorkoutType.strength,
  createdAt: day.toLocalDateTime().add(const Duration(hours: 7)),
);

void main() {
  test('nothing to group gives no months', () {
    expect(HistoryMonth.group(const []), isEmpty);
  });

  test('groups by month, newest month and newest check-in first', () {
    final oct30 = _checkInOn(CalendarDay(2026, 10, 30));
    final nov2 = _checkInOn(CalendarDay(2026, 11, 2));
    final nov6 = _checkInOn(CalendarDay(2026, 11, 6));
    final oct1 = _checkInOn(CalendarDay(2026, 10, 1));

    // The repository's order, oldest first, but any order works.
    final months = HistoryMonth.group([nov2, oct1, nov6, oct30]);

    expect(months, [
      HistoryMonth(year: 2026, month: 11, checkIns: [nov6, nov2]),
      HistoryMonth(year: 2026, month: 10, checkIns: [oct30, oct1]),
    ]);
  });

  test('leaves out months without a check-in', () {
    final aug = _checkInOn(CalendarDay(2026, 8, 14));
    final nov = _checkInOn(CalendarDay(2026, 11, 6));

    expect(HistoryMonth.group([aug, nov]).map((month) => month.month), [11, 8]);
  });

  test('keeps the same month of different years apart', () {
    final thisYear = _checkInOn(CalendarDay(2026, 1, 3));
    final lastYear = _checkInOn(CalendarDay(2025, 1, 3));

    expect(HistoryMonth.group([lastYear, thisYear]), [
      HistoryMonth(year: 2026, month: 1, checkIns: [thisYear]),
      HistoryMonth(year: 2025, month: 1, checkIns: [lastYear]),
    ]);
  });

  test("a month's check-ins can't be changed from outside", () {
    final month = HistoryMonth.group([
      _checkInOn(CalendarDay(2026, 11, 6)),
    ]).single;

    expect(
      () => month.checkIns.add(_checkInOn(CalendarDay(2026, 11, 7))),
      throwsUnsupportedError,
    );
  });
}
