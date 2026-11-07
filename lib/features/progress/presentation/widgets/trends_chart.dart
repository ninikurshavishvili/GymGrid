import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/date/calendar_day.dart';
import '../../domain/entities/trends.dart';

/// Effort and energy over the range, as lines on a 0 to 100% scale.
///
/// The counterpart of a Swift Charts `Chart` with a `LineMark` per series:
/// effort solid green, energy dashed blue, so the two differ by more than
/// colour. Touching or dragging shows the values under the finger. The
/// screen gives VoiceOver a summary in its place, since a drawing can't be
/// read out.
class TrendsChart extends StatelessWidget {
  const TrendsChart({
    required this.trends,
    required this.showsEffort,
    required this.showsEnergy,
    super.key,
  });

  final Trends trends;
  final bool showsEffort;
  final bool showsEnergy;

  /// The plotting area's height. The date labels below add to it.
  static const double plotHeight = 200;

  /// Dash and gap lengths of the energy line, and of its sample in the
  /// line toggles.
  static const List<int> energyDashes = [6, 4];

  /// How close a finger has to be to a point to show it.
  static const double _touchDistance = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = context.textStyles.footnote.copyWith(
      color: colors.textSecondary,
    );
    final localizations = MaterialLocalizations.of(context);
    final start = trends.start;

    final lines = [
      if (showsEffort && trends.effort.points.isNotEmpty)
        (
          name: 'Effort',
          line: trends.effort,
          color: colors.chartEffort,
          dashes: null,
        ),
      if (showsEnergy && trends.energy.points.isNotEmpty)
        (
          name: 'Energy',
          line: trends.energy,
          color: colors.chartEnergy,
          dashes: energyDashes,
        ),
    ];

    CalendarDay dayAt(double x) => start.addDays(x.round());
    String shortDate(CalendarDay day) =>
        localizations.formatShortMonthDay(day.toLocalDateTime());
    // A year's points are weeks, which end on the point's day.
    String pointDate(double x) => trends.range.isWeekly
        ? 'Week of ${shortDate(dayAt(x).addDays(1 - DateTime.daysPerWeek))}'
        : shortDate(dayAt(x));

    final measure = _TextMeasure(context, labelStyle);
    final lastX = (trends.range.days - 1).toDouble();
    final dateLabelHeight = measure.size('Nov 30').height + AppSpacing.sm;

    return SizedBox(
      height: plotHeight + dateLabelHeight,
      child: LineChart(
        duration: context.motionDuration,
        LineChartData(
          minX: 0,
          maxX: lastX,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            for (final (name: _, :line, :color, :dashes) in lines)
              LineChartBarData(
                spots: _spotsOf(line, start),
                color: color,
                barWidth: 2,
                isStrokeCapRound: true,
                dashArray: dashes,
                // Dots too, so a lone rating between gaps still shows.
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 3,
                        color: color,
                        strokeWidth: 0,
                      ),
                ),
              ),
          ],
          // A line for each rating step, which is all the scale needs.
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: colors.bgTertiary, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            // Percentages on the right, as in Apple Health.
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 50,
                reservedSize: measure.size('100%').width + AppSpacing.sm,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('${value.round()}%', style: labelStyle),
                ),
              ),
            ),
            // The first, middle and last day, enough to place any point.
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: lastX / 2,
                reservedSize: dateLabelHeight,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  // Keeps the first and last labels from being cut off.
                  fitInside: SideTitleFitInsideData.fromTitleMeta(
                    meta,
                    distanceFromEdge: 0,
                  ),
                  child: Text(shortDate(dayAt(value)), style: labelStyle),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchSpotThreshold: _touchDistance,
            getTouchedSpotIndicator: (bar, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(color: colors.textMuted, strokeWidth: 1),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: 5,
                          color: bar.color ?? colors.textPrimary,
                          strokeWidth: 2,
                          strokeColor: colors.bgSecondary,
                        ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => colors.bgTertiary,
              tooltipBorderRadius: BorderRadius.circular(AppRadius.md),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: measure
                  .size('Week of Nov 30 · Energy 100%')
                  .width,
              getTooltipItems: (touched) {
                // Usually both lines are touched on the same day, which then
                // heads the tooltip. Otherwise each line names its own.
                final sameDay = touched.every(
                  (spot) => spot.x == touched.first.x,
                );
                return [
                  for (final (index, spot) in touched.indexed)
                    LineTooltipItem(
                      [
                        if (sameDay && index == 0) '${pointDate(spot.x)}\n',
                        if (!sameDay) '${pointDate(spot.x)} · ',
                        '${lines[spot.barIndex].name} ${spot.y.round()}%',
                      ].join(),
                      labelStyle.copyWith(color: colors.textPrimary),
                    ),
                ];
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The line's points, with a gap wherever it breaks.
  static List<FlSpot> _spotsOf(TrendLine line, CalendarDay start) => [
    for (final (index, segment) in line.segments.indexed) ...[
      // fl_chart leaves the line out between the points either side of a
      // null spot.
      if (index > 0) FlSpot.nullSpot,
      for (final point in segment)
        FlSpot(point.day.daysSince(start).toDouble(), point.percent),
    ],
  ];
}

/// Measures text as it will be drawn, at the current text size, to size the
/// chart's label areas, which fl_chart needs to know up front.
class _TextMeasure {
  _TextMeasure(BuildContext context, this._style)
    : _scaler = MediaQuery.textScalerOf(context),
      _direction = Directionality.of(context);

  final TextStyle _style;
  final TextScaler _scaler;
  final TextDirection _direction;

  Size size(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style),
      textScaler: _scaler,
      textDirection: _direction,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }
}
