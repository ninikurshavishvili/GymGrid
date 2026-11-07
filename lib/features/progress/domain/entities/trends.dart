import 'package:equatable/equatable.dart';

import '../../../../core/date/calendar_day.dart';
import '../../../check_in/domain/entities/check_in.dart';
import '../../../check_in/domain/entities/rating.dart';

/// How far back the Trends chart looks, always ending today.
///
/// Rolling windows rather than calendar months, like Apple Health, so the
/// chart is never half empty early in a month.
enum TrendRange {
  /// The last 30 days, a point for each rated check-in.
  month(days: 30),

  /// The last 90 days, a point for each rated check-in.
  threeMonths(days: 90),

  /// The last 52 weeks, a point for each week: the average of its ratings.
  ///
  /// A point per check-in would crowd 200 or more into a phone's width.
  /// 52 whole weeks, rather than 365 days, so every week is complete.
  year(days: 52 * DateTime.daysPerWeek, isWeekly: true);

  const TrendRange({required this.days, this.isWeekly = false});

  /// How many days the range covers, today included.
  final int days;

  /// Whether each point is a week's average rather than one check-in.
  final bool isWeekly;

  /// The first day in the range that ends on [today].
  CalendarDay startFor(CalendarDay today) => today.addDays(1 - days);
}

/// One point on a line: a percentage on a day.
class TrendPoint extends Equatable {
  const TrendPoint(this.day, this.percent);

  /// The check-in's day, or the last day of the week it averages.
  final CalendarDay day;

  /// 20 to 100. A week's average can fall between the steps.
  final double percent;

  @override
  List<Object?> get props => [day, percent];
}

/// One line on the chart, such as effort, over a [TrendRange].
class TrendLine extends Equatable {
  const TrendLine({
    required this.points,
    required this.average,
    required this.previousAverage,
  });

  /// More days than this with no rating break the line, rather than join
  /// ratings far apart with a slope nobody felt. A gym day each week stays
  /// joined; a week away breaks it.
  static const int maxGapDays = DateTime.daysPerWeek;

  /// Oldest first. Days without a rating have no point, rather than a point
  /// at 0%: an unrated day says nothing about how it felt.
  final List<TrendPoint> points;

  /// The average of every rating in the range, or null if there's none.
  /// Taken over the ratings themselves, even where [points] are weekly.
  final double? average;

  /// The same for the equal stretch of time just before the range, for "up
  /// from 65%". Null if there's no rating there.
  final double? previousAverage;

  /// [points] split wherever more than [maxGapDays] pass between two of
  /// them, each part drawn as its own stretch of line.
  List<List<TrendPoint>> get segments {
    final segments = <List<TrendPoint>>[];
    TrendPoint? previous;
    for (final point in points) {
      if (previous == null || point.day.daysSince(previous.day) > maxGapDays) {
        segments.add([]);
      }
      segments.last.add(point);
      previous = point;
    }
    return segments;
  }

  @override
  List<Object?> get props => [points, average, previousAverage];
}

/// How effort and energy went over a [TrendRange], as of [today].
class Trends extends Equatable {
  const Trends({
    required this.range,
    required this.today,
    required this.effort,
    required this.energy,
    required this.hasRatings,
  });

  /// Works out both lines from every check-in.
  ///
  /// Check-ins after [today], which appear only if the device clock was
  /// moved back, are left out, as on the year grid.
  factory Trends.from(
    Iterable<CheckIn> checkIns, {
    required TrendRange range,
    required CalendarDay today,
  }) {
    final upToToday = [
      for (final checkIn in checkIns)
        if (!checkIn.date.isAfter(today)) checkIn,
    ];

    return Trends(
      range: range,
      today: today,
      effort: _line(upToToday, (checkIn) => checkIn.effort, range, today),
      energy: _line(upToToday, (checkIn) => checkIn.energy, range, today),
      hasRatings: upToToday.any(
        (checkIn) => checkIn.effort != null || checkIn.energy != null,
      ),
    );
  }

  final TrendRange range;
  final CalendarDay today;
  final TrendLine effort;
  final TrendLine energy;

  /// Whether the user has ever rated a check-in, in this range or not. Until
  /// then there's nothing to chart, and the screen explains the feature.
  final bool hasRatings;

  /// The first day the chart shows.
  CalendarDay get start => range.startFor(today);

  static TrendLine _line(
    List<CheckIn> checkIns,
    Rating? Function(CheckIn) ratingOf,
    TrendRange range,
    CalendarDay today,
  ) {
    final start = range.startFor(today);
    final previousStart = start.addDays(-range.days);

    final inRange = <TrendPoint>[];
    final before = <double>[];
    for (final checkIn in checkIns) {
      final percent = ratingOf(checkIn)?.percent.toDouble();
      if (percent == null) continue;

      final day = checkIn.date;
      if (!day.isBefore(start)) {
        inRange.add(TrendPoint(day, percent));
      } else if (!day.isBefore(previousStart)) {
        before.add(percent);
      }
    }
    inRange.sort((a, b) => a.day.daysSince(b.day));

    return TrendLine(
      points: range.isWeekly ? _weekly(inRange, start) : inRange,
      average: _average([for (final point in inRange) point.percent]),
      previousAverage: _average(before),
    );
  }

  /// One point per week that has a rating, counting weeks from [start], so
  /// the last one ends today. Each sits on its week's last day.
  static List<TrendPoint> _weekly(List<TrendPoint> points, CalendarDay start) {
    final weeks = <int, List<double>>{};
    for (final point in points) {
      final week = point.day.daysSince(start) ~/ DateTime.daysPerWeek;
      (weeks[week] ??= []).add(point.percent);
    }
    return [
      for (final MapEntry(key: week, value: percents) in weeks.entries)
        TrendPoint(
          start.addDays((week + 1) * DateTime.daysPerWeek - 1),
          _average(percents)!,
        ),
    ];
  }

  static double? _average(List<double> values) => values.isEmpty
      ? null
      : values.reduce((sum, value) => sum + value) / values.length;

  @override
  List<Object?> get props => [range, today, effort, energy, hasRatings];
}
