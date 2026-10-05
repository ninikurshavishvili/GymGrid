import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/progress/domain/entities/streak_summary.dart';

void main() {
  // A Monday.
  final today = CalendarDay(2026, 10, 5);

  /// The day [days] days before [today].
  CalendarDay ago(int days) => today.addDays(-days);

  StreakSummary streaksFor(List<CalendarDay> days) =>
      StreakSummary.from(days, today: today);

  test('with no check-ins, everything is zero', () {
    expect(
      streaksFor([]),
      const StreakSummary(current: 0, longest: 0, isAtRisk: false),
    );
  });

  group('current streak', () {
    test('counts consecutive days ending today', () {
      expect(streaksFor([ago(2), ago(1), ago(0)]).current, 3);
    });

    test('with no check-in yet today, counts back from yesterday', () {
      expect(streaksFor([ago(3), ago(2), ago(1)]).current, 3);
    });

    test('is 0 once a whole day passes without a check-in', () {
      expect(streaksFor([ago(4), ago(3), ago(2)]).current, 0);
    });

    test('restarts at 1 after a missed day', () {
      expect(streaksFor([ago(4), ago(3), ago(2), ago(0)]).current, 1);
    });

    test('stops at the most recent gap', () {
      final days = [ago(6), ago(5), ago(4), ago(2), ago(1), ago(0)];

      expect(streaksFor(days).current, 3);
    });

    test('ignores check-ins after today', () {
      // Possible only if the device clock was moved back.
      expect(streaksFor([ago(1), ago(0), today.addDays(1)]).current, 2);
    });
  });

  group('at risk', () {
    for (final (checkedInYesterday, checkedInToday, isAtRisk) in [
      (true, false, true),
      (true, true, false),
      (false, true, false),
      (false, false, false),
    ]) {
      test('${isAtRisk ? 'is' : 'is not'} at risk with '
          '${checkedInYesterday ? 'a' : 'no'} check-in yesterday and '
          '${checkedInToday ? 'one' : 'none'} today', () {
        final days = [
          ago(3),
          ago(2),
          if (checkedInYesterday) ago(1),
          if (checkedInToday) ago(0),
        ];

        expect(streaksFor(days).isAtRisk, isAtRisk);
      });
    }
  });

  group('longest streak', () {
    test('is the longest run anywhere in the history', () {
      final summary = streaksFor([
        ago(30),
        ago(29),
        ago(28),
        ago(27),
        ago(10),
        ago(9),
        ago(0),
      ]);

      expect(summary.longest, 4);
      expect(summary.current, 1);
    });

    test('includes the current streak', () {
      expect(streaksFor([ago(10), ago(2), ago(1), ago(0)]).longest, 3);
    });

    test('includes a streak that is at risk', () {
      expect(streaksFor([ago(10), ago(2), ago(1)]).longest, 2);
    });
  });

  test('ignores duplicate and unordered days', () {
    expect(
      streaksFor([ago(0), ago(2), ago(1), ago(0), ago(1)]),
      const StreakSummary(current: 3, longest: 3, isAtRisk: false),
    );
  });

  group('calendar boundaries', () {
    test('a streak continues from 31 December into the new year', () {
      final summary = StreakSummary.from([
        CalendarDay(2026, 12, 30),
        CalendarDay(2026, 12, 31),
        CalendarDay(2027, 1, 1),
      ], today: CalendarDay(2027, 1, 1));

      expect(
        summary,
        const StreakSummary(current: 3, longest: 3, isAtRisk: false),
      );
    });

    test('on 1 January, a streak ending 31 December is at risk, not lost', () {
      final summary = StreakSummary.from([
        CalendarDay(2026, 12, 30),
        CalendarDay(2026, 12, 31),
      ], today: CalendarDay(2027, 1, 1));

      expect(
        summary,
        const StreakSummary(current: 2, longest: 2, isAtRisk: true),
      );
    });

    test('29 February extends a streak in a leap year', () {
      final summary = StreakSummary.from([
        CalendarDay(2028, 2, 28),
        CalendarDay(2028, 2, 29),
        CalendarDay(2028, 3, 1),
      ], today: CalendarDay(2028, 3, 1));

      expect(summary.current, 3);
    });

    test('missing 29 February breaks a streak in a leap year', () {
      final summary = StreakSummary.from([
        CalendarDay(2028, 2, 28),
        CalendarDay(2028, 3, 1),
      ], today: CalendarDay(2028, 3, 1));

      expect(summary.current, 1);
      expect(summary.longest, 1);
    });

    test('28 February runs into 1 March in other years', () {
      final summary = StreakSummary.from([
        CalendarDay(2027, 2, 28),
        CalendarDay(2027, 3, 1),
      ], today: CalendarDay(2027, 3, 1));

      expect(summary.current, 2);
    });

    test('a streak continues across a daylight saving change', () {
      final summary = StreakSummary.from([
        CalendarDay(2026, 10, 24),
        CalendarDay(2026, 10, 25),
        CalendarDay(2026, 10, 26),
      ], today: CalendarDay(2026, 10, 26));

      expect(summary.current, 3);
    });
  });
}
