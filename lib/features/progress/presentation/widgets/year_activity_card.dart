import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/date/calendar_day.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../check_in/domain/entities/check_in.dart';
import '../../../check_in/presentation/workout_type_labels.dart';
import '../../domain/entities/progress.dart';
import '../../domain/entities/year_grid.dart';

/// The year at a glance: a total and a contribution-style grid of days.
///
/// A year has too many columns to fit legibly on a phone, so the grid
/// scrolls sideways and opens on the current week. Tapping a filled day
/// calls [onDayTap].
class YearActivityCard extends StatelessWidget {
  const YearActivityCard({
    required this.progress,
    required this.onDayTap,
    super.key,
  });

  final Progress progress;
  final ValueChanged<CalendarDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;

    final year = progress.today.year;
    final count = progress.checkInCountThisYear;
    final countLabel = count == 1 ? '1 check-in' : '$count check-ins';
    final checkInsByDay = {
      for (final checkIn in progress.checkIns) checkIn.date: checkIn,
    };

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Semantics(
        container: true,
        label: '$year activity, $countLabel',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              // Already part of the card's label. A Wrap so the count moves
              // to its own line at large text sizes.
              child: ExcludeSemantics(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$year',
                      style: text.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      countLabel,
                      style: text.footnote.copyWith(color: colors.gridFilled),
                    ),
                  ],
                ),
              ),
            ),
            // The squares are a fixed size, so their axis labels stop short
            // of the largest text sizes to stay aligned with them. VoiceOver
            // users get each day's full date instead.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: _Grid.maxLabelScale,
              child: _Grid(
                grid: YearGrid.build(
                  year: year,
                  checkInDays: checkInsByDay.keys.toSet(),
                  today: progress.today,
                ),
                checkInsByDay: checkInsByDay,
                onDayTap: onDayTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatefulWidget {
  const _Grid({
    required this.grid,
    required this.checkInsByDay,
    required this.onDayTap,
  });

  static const double maxLabelScale = 1.3;

  static const double cellSize = 14;

  /// A cell's square plus the gap after it. The gap belongs to the cell so
  /// a tap between two squares still lands on one of them.
  static const double cellPitch = cellSize + AppSpacing.xs - 1;

  final YearGrid grid;
  final Map<CalendarDay, CheckIn> checkInsByDay;
  final ValueChanged<CalendarDay> onDayTap;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  static const double _endPadding = AppSpacing.lg;

  /// Created on the first layout, the first time the viewport's width is
  /// known, so the very first frame is already at the current week.
  ScrollController? _scrollController;

  double _initialOffset(double viewportWidth) {
    final todayColumn = widget.grid.todayColumn;
    if (todayColumn == null) return 0;

    double widthThrough(int columns) => columns * _Grid.cellPitch + _endPadding;

    final maxOffset = widthThrough(widget.grid.weeks.length) - viewportWidth;
    final todayOffset = widthThrough(todayColumn + 1) - viewportWidth;
    return todayOffset.clamp(0, math.max(0, maxOffset));
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(
            start: AppSpacing.lg,
            end: AppSpacing.xs,
          ),
          child: ExcludeSemantics(child: _DayLabels()),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final controller = _scrollController ??= ScrollController(
                initialScrollOffset: _initialOffset(constraints.maxWidth),
              );

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: controller,
                padding: const EdgeInsetsDirectional.only(end: _endPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    ExcludeSemantics(child: _MonthLabels(grid: widget.grid)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final week in widget.grid.weeks)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final cell in week.cells)
                                _Cell(
                                  cell: cell,
                                  checkIn: widget.checkInsByDay[cell.day],
                                  onTap: widget.onDayTap,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// M, W and F beside the rows. Stays put while the grid scrolls.
class _DayLabels extends StatelessWidget {
  const _DayLabels();

  static const List<String> _labels = ['M', '', 'W', '', 'F', '', ''];

  @override
  Widget build(BuildContext context) {
    final style = context.textStyles.badge.copyWith(
      color: context.colors.textSecondary,
      height: 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        // Takes the same height as the month labels, to line up with the
        // first row of squares.
        Text(' ', style: context.textStyles.badge),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final label in _labels)
              SizedBox(
                height: _Grid.cellPitch,
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Text(
                    label,
                    style: style,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels({required this.grid});

  final YearGrid grid;

  static const List<String> _names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final starts = grid.monthStartColumns;
    final style = context.textStyles.badge.copyWith(
      color: context.colors.textSecondary,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, name) in _names.indexed)
          SizedBox(
            width:
                ((index + 1 < starts.length
                        ? starts[index + 1]
                        : grid.weeks.length) -
                    starts[index]) *
                _Grid.cellPitch,
            child: Text(
              name,
              style: style,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.checkIn, required this.onTap});

  final YearGridCell cell;

  /// The day's check-in, which a filled cell always has.
  final CheckIn? checkIn;

  final ValueChanged<CalendarDay> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.xs);

    final decoration = switch (cell.state) {
      YearGridCellState.outsideYear => null,
      YearGridCellState.filled => BoxDecoration(
        color: colors.gridFilled,
        borderRadius: radius,
      ),
      YearGridCellState.empty => BoxDecoration(
        color: colors.gridEmpty,
        borderRadius: radius,
      ),
      YearGridCellState.future => BoxDecoration(
        color: colors.gridEmpty.withValues(alpha: 0.4),
        borderRadius: radius,
      ),
      YearGridCellState.today => BoxDecoration(
        color: colors.gridEmpty,
        borderRadius: radius,
        border: Border.all(color: colors.actionGreenBorder, width: 1.5),
      ),
    };

    final square = SizedBox.square(
      dimension: _Grid.cellPitch,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox.square(
          dimension: _Grid.cellSize,
          child: decoration == null
              ? null
              : DecoratedBox(decoration: decoration),
        ),
      ),
    );

    final day = cell.day;
    final checkIn = this.checkIn;
    // Only filled days do anything, and only they are announced: reading out
    // 300 empty days would make VoiceOver unusable here.
    if (cell.state != YearGridCellState.filled ||
        day == null ||
        checkIn == null) {
      return square;
    }

    final date = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(day.toLocalDateTime());

    return Semantics(
      container: true,
      button: true,
      label: '$date, checked in, ${checkIn.workoutType.label.toLowerCase()}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(day),
        child: square,
      ),
    );
  }
}
