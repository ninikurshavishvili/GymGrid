import '../domain/entities/trends.dart';

/// How a [TrendRange] is written in the app.
extension TrendRangeLabels on TrendRange {
  /// On the range control: "Month", "3 Months" or "Year".
  String get title => switch (this) {
    TrendRange.month => 'Month',
    TrendRange.threeMonths => '3 Months',
    TrendRange.year => 'Year',
  };

  /// The range in a sentence: "the past month".
  String get period => switch (this) {
    TrendRange.month => 'the past month',
    TrendRange.threeMonths => 'the past 3 months',
    TrendRange.year => 'the past year',
  };

  /// The stretch before it, for comparisons: "the month before".
  String get periodBefore => switch (this) {
    TrendRange.month => 'the month before',
    TrendRange.threeMonths => 'the 3 months before',
    TrendRange.year => 'the year before',
  };
}

/// The sentences under the chart, which VoiceOver also reads in place of
/// the chart itself.
extension TrendsSummary on Trends {
  /// Both lines, effort first, such as "Effort averaged 72%, up from 65% the
  /// month before."
  List<String> get summaries => [
    _summaryOf('Effort', effort),
    _summaryOf('Energy', energy),
  ];

  /// The chart's VoiceOver label: what it shows, then [summaries].
  String get chartLabel =>
      ['Effort and energy over ${range.period}.', ...summaries].join(' ');

  String _summaryOf(String name, TrendLine line) {
    final average = line.average?.round();
    if (average == null) {
      return 'No ${name.toLowerCase()} ratings in ${range.period}.';
    }

    final sentence = '$name averaged $average%';
    final before = line.previousAverage?.round();
    if (before == null) return '$sentence.';
    if (before == average) {
      return '$sentence, the same as ${range.periodBefore}.';
    }
    final direction = average > before ? 'up' : 'down';
    return '$sentence, $direction from $before% ${range.periodBefore}.';
  }
}
