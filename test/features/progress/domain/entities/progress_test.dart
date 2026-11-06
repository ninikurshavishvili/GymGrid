import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/progress/domain/entities/progress.dart';
import 'package:gym_grid/features/progress/domain/entities/streak_summary.dart';

void main() {
  final today = CalendarDay(2026, 10, 5);

  CheckIn checkInOn(CalendarDay date) => CheckIn(
    id: date.toIso8601String(),
    date: date,
    photoPath: 'photos/$date.jpg',
    workoutType: WorkoutType.strength,
    createdAt: date.toLocalDateTime(),
  );

  test('is empty before the first check-in', () {
    final progress = Progress.from(const [], today: today);

    expect(progress.checkIns, isEmpty);
    expect(progress.today, today);
    expect(
      progress.streaks,
      const StreakSummary(current: 0, longest: 0, isAtRisk: false),
    );
    expect(progress.todaysCheckIn, isNull);
    expect(progress.checkInCountThisYear, 0);
  });

  test('keeps every check-in', () {
    final checkIns = [checkInOn(today.addDays(-1)), checkInOn(today)];

    expect(Progress.from(checkIns, today: today).checkIns, checkIns);
  });

  test("finds today's check-in", () {
    final todays = checkInOn(today);

    final progress = Progress.from([
      checkInOn(today.addDays(-1)),
      todays,
    ], today: today);

    expect(progress.todaysCheckIn, todays);
  });

  test("has no check-in for today when the latest is yesterday's", () {
    final progress = Progress.from([
      checkInOn(today.addDays(-1)),
    ], today: today);

    expect(progress.todaysCheckIn, isNull);
  });

  test('works out streaks from the check-in days', () {
    final progress = Progress.from([
      checkInOn(today.addDays(-2)),
      checkInOn(today.addDays(-1)),
    ], today: today);

    expect(
      progress.streaks,
      const StreakSummary(current: 2, longest: 2, isAtRisk: true),
    );
  });

  test('counts only check-ins from the current year', () {
    final progress = Progress.from([
      checkInOn(CalendarDay(2025, 12, 31)),
      checkInOn(CalendarDay(2026, 1, 1)),
      checkInOn(today),
    ], today: today);

    expect(progress.checkInCountThisYear, 2);
  });

  test('ignores check-ins after today, which the year grid leaves out', () {
    final progress = Progress.from([
      checkInOn(today),
      checkInOn(today.addDays(1)),
    ], today: today);

    expect(progress.checkInCountThisYear, 1);
  });

  test('on 1 January the count restarts and the streak carries on', () {
    final newYearsDay = CalendarDay(2027, 1, 1);

    final progress = Progress.from([
      checkInOn(CalendarDay(2026, 12, 30)),
      checkInOn(CalendarDay(2026, 12, 31)),
      checkInOn(newYearsDay),
    ], today: newYearsDay);

    expect(progress.checkInCountThisYear, 1);
    expect(progress.streaks.current, 3);
  });

  test('progress with the same values is equal', () {
    final checkIns = [checkInOn(today)];

    expect(
      Progress.from(checkIns, today: today),
      Progress.from(List.of(checkIns), today: today),
    );
  });
}
