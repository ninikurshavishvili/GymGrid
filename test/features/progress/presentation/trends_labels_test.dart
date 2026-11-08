import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/progress/domain/entities/trends.dart';
import 'package:gym_grid/features/progress/presentation/trends_labels.dart';

void main() {
  final today = CalendarDay(2026, 11, 7);

  TrendLine lineWith({double? average, double? previousAverage}) => TrendLine(
    points: [if (average != null) TrendPoint(today, average)],
    average: average,
    previousAverage: previousAverage,
  );

  Trends trendsWith({
    TrendRange range = TrendRange.month,
    TrendLine? effort,
    TrendLine? energy,
  }) => Trends(
    range: range,
    today: today,
    effort: effort ?? lineWith(),
    energy: energy ?? lineWith(),
    hasRatings: true,
  );

  group('range labels', () {
    test('name each range on the control and in sentences', () {
      expect(TrendRange.values.map((range) => range.title), [
        'Month',
        '3 Months',
        'Year',
      ]);
      expect(TrendRange.threeMonths.period, 'the past 3 months');
      expect(TrendRange.year.periodBefore, 'the year before');
    });
  });

  group('summaries', () {
    test('say which way an average moved, in whole percent', () {
      final trends = trendsWith(
        effort: lineWith(average: 72.4, previousAverage: 65),
        energy: lineWith(average: 50, previousAverage: 61.6),
      );

      expect(trends.summaries, [
        'Effort averaged 72%, up from 65% the month before.',
        'Energy averaged 50%, down from 62% the month before.',
      ]);
    });

    test('say when nothing changed, once rounded', () {
      final trends = trendsWith(
        range: TrendRange.threeMonths,
        effort: lineWith(average: 60.2, previousAverage: 59.8),
      );

      expect(
        trends.summaries.first,
        'Effort averaged 60%, the same as the 3 months before.',
      );
    });

    test('leave out a comparison with nothing to compare', () {
      final trends = trendsWith(effort: lineWith(average: 80));

      expect(trends.summaries.first, 'Effort averaged 80%.');
    });

    test('say when a line has no ratings in the range', () {
      final trends = trendsWith(
        range: TrendRange.year,
        effort: lineWith(average: 40),
      );

      expect(trends.summaries.last, 'No energy ratings in the past year.');
    });

    test('make up the chart label, after what it shows', () {
      final trends = trendsWith(
        effort: lineWith(average: 80, previousAverage: 60),
      );

      expect(
        trends.chartLabel,
        'Effort and energy over the past month. Effort averaged 80%, up '
        'from 60% the month before. No energy ratings in the past month.',
      );
    });
  });
}
