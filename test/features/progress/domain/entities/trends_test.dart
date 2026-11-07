import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/progress/domain/entities/trends.dart';

void main() {
  final today = CalendarDay(2026, 11, 7);

  CheckIn checkInOn(CalendarDay day, {Rating? effort, Rating? energy}) {
    return CheckIn(
      id: '$day',
      date: day,
      photoPaths: const ['photos/1.jpg'],
      workoutType: WorkoutType.strength,
      effort: effort,
      energy: energy,
      createdAt: day.toLocalDateTime(),
    );
  }

  /// The check-in [daysAgo] days before today.
  CheckIn ago(int daysAgo, {Rating? effort, Rating? energy}) =>
      checkInOn(today.addDays(-daysAgo), effort: effort, energy: energy);

  Trends trendsOf(
    List<CheckIn> checkIns, {
    TrendRange range = TrendRange.month,
  }) => Trends.from(checkIns, range: range, today: today);

  group('TrendRange', () {
    test('covers 30 days, 90 days or 52 whole weeks, today included', () {
      expect(TrendRange.month.days, 30);
      expect(TrendRange.threeMonths.days, 90);
      expect(TrendRange.year.days, 364);
      expect(TrendRange.month.startFor(today), CalendarDay(2026, 10, 9));
      expect(TrendRange.year.startFor(today), CalendarDay(2025, 11, 9));
    });

    test('only the year shows weekly points', () {
      expect(TrendRange.month.isWeekly, isFalse);
      expect(TrendRange.threeMonths.isWeekly, isFalse);
      expect(TrendRange.year.isWeekly, isTrue);
    });
  });

  group('a month', () {
    test('has a point for each rated check-in in range, oldest first', () {
      final trends = trendsOf([
        ago(0, effort: Rating.high),
        ago(29, effort: Rating.low),
        ago(30, effort: Rating.max),
        ago(10, effort: Rating.medium),
      ]);

      expect(trends.effort.points, [
        TrendPoint(today.addDays(-29), 40),
        TrendPoint(today.addDays(-10), 60),
        TrendPoint(today, 80),
      ]);
      expect(trends.start, today.addDays(-29));
    });

    test('leaves out unrated check-ins rather than counting them as 0', () {
      final trends = trendsOf([ago(1), ago(2, effort: Rating.max), ago(3)]);

      expect(trends.effort.points, [TrendPoint(today.addDays(-2), 100)]);
      expect(trends.effort.average, 100);
    });

    test('keeps effort and energy apart', () {
      final trends = trendsOf([
        ago(1, effort: Rating.veryLow),
        ago(2, energy: Rating.high),
        ago(3, effort: Rating.max, energy: Rating.low),
      ]);

      expect(trends.effort.points.map((point) => point.percent), [100, 20]);
      expect(trends.energy.points.map((point) => point.percent), [40, 80]);
    });

    test('leaves out days after today', () {
      final trends = trendsOf([
        checkInOn(today.addDays(1), effort: Rating.max),
        ago(0, effort: Rating.low),
      ]);

      expect(trends.effort.points, [TrendPoint(today, 40)]);
    });
  });

  group('averages', () {
    test('cover the range, and the same length of time before it', () {
      final trends = trendsOf([
        ago(1, effort: Rating.high),
        ago(5, effort: Rating.medium),
        // The 30 days before the range: 30 to 59 days ago.
        ago(30, effort: Rating.low),
        ago(59, effort: Rating.medium),
        // Further back still, so left out.
        ago(60, effort: Rating.max),
      ]);

      expect(trends.effort.average, 70);
      expect(trends.effort.previousAverage, 50);
    });

    test('are null without ratings to average', () {
      final trends = trendsOf([ago(1, effort: Rating.high)]);

      expect(trends.effort.previousAverage, isNull);
      expect(trends.energy.average, isNull);
      expect(trends.energy.previousAverage, isNull);
      expect(trends.energy.points, isEmpty);
    });

    test('use the full length of the longer ranges', () {
      final trends = trendsOf([
        ago(89, effort: Rating.veryLow),
        ago(90, effort: Rating.max),
      ], range: TrendRange.threeMonths);

      expect(trends.effort.average, 20);
      expect(trends.effort.previousAverage, 100);
    });
  });

  group('a year', () {
    test('has a point for each week with a rating, its average, on the '
        "week's last day", () {
      final trends = trendsOf([
        // This week: today and the six days before.
        ago(0, effort: Rating.high),
        ago(6, effort: Rating.medium),
        // The week before.
        ago(7, effort: Rating.veryLow),
        // The first week of the year's range.
        ago(363, effort: Rating.max),
      ], range: TrendRange.year);

      expect(trends.effort.points, [
        TrendPoint(today.addDays(-357), 100),
        TrendPoint(today.addDays(-7), 20),
        TrendPoint(today, 70),
      ]);
    });

    test('averages the ratings themselves, not the weeks', () {
      final trends = trendsOf([
        ago(0, effort: Rating.veryLow),
        ago(1, effort: Rating.low),
        ago(2, effort: Rating.medium),
        ago(7, effort: Rating.max),
      ], range: TrendRange.year);

      // Weeks of 40% and 100% would average 70%; the four ratings, 55%.
      expect(trends.effort.average, 55);
    });

    test('compares with the 52 weeks before', () {
      final trends = trendsOf([
        ago(0, energy: Rating.high),
        ago(364, energy: Rating.low),
        ago(728, energy: Rating.max),
      ], range: TrendRange.year);

      expect(trends.energy.previousAverage, 40);
    });
  });

  group('segments', () {
    List<List<int>> daysAgoBySegment(Trends trends) => [
      for (final segment in trends.effort.segments)
        [for (final point in segment) today.daysSince(point.day)],
    ];

    test('join ratings up to a week apart', () {
      final trends = trendsOf([
        ago(14, effort: Rating.low),
        ago(7, effort: Rating.medium),
        ago(0, effort: Rating.high),
      ]);

      expect(daysAgoBySegment(trends), [
        [14, 7, 0],
      ]);
    });

    test('break after more than a week without a rating', () {
      final trends = trendsOf([
        ago(20, effort: Rating.low),
        ago(19, effort: Rating.low),
        ago(10, effort: Rating.medium),
        ago(0, effort: Rating.high),
      ]);

      expect(daysAgoBySegment(trends), [
        [20, 19],
        [10],
        [0],
      ]);
    });

    test('break where a whole week of the year has no rating', () {
      final trends = trendsOf([
        ago(0, effort: Rating.high),
        ago(7, effort: Rating.high),
        ago(21, effort: Rating.high),
      ], range: TrendRange.year);

      expect(daysAgoBySegment(trends), [
        [21],
        [7, 0],
      ]);
    });

    test('are empty without points', () {
      expect(trendsOf(const []).effort.segments, isEmpty);
    });
  });

  group('hasRatings', () {
    test('is false until a check-in is rated', () {
      expect(trendsOf(const []).hasRatings, isFalse);
      expect(trendsOf([ago(0), ago(1)]).hasRatings, isFalse);
    });

    test('counts a rating outside the range, so the screen can say the '
        'range is empty rather than explain the feature', () {
      final trends = trendsOf([ago(100, energy: Rating.low)]);

      expect(trends.hasRatings, isTrue);
      expect(trends.energy.points, isEmpty);
    });

    test('ignores a rating after today', () {
      final trends = trendsOf([
        checkInOn(today.addDays(3), effort: Rating.high),
      ]);

      expect(trends.hasRatings, isFalse);
    });
  });
}
