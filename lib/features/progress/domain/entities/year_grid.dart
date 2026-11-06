import 'package:equatable/equatable.dart';

import '../../../../core/date/calendar_day.dart';

/// What a cell of the year grid shows.
enum YearGridCellState {
  /// Padding before 1 January or after 31 December. Not drawn.
  outsideYear,

  /// A day after today. A check-in here, which can exist only if the device
  /// clock was moved back, doesn't fill it.
  future,

  /// A day before today without a check-in.
  empty,

  /// A day up to and including today with a check-in.
  filled,

  /// Today, until the user checks in; after that it's [filled].
  today,
}

/// One square of the year grid.
class YearGridCell extends Equatable {
  const YearGridCell({required this.state, this.day});

  /// Null only for [YearGridCellState.outsideYear].
  final CalendarDay? day;

  final YearGridCellState state;

  @override
  List<Object?> get props => [day, state];
}

/// One column of the year grid: [cells] holds seven days, Monday first.
class YearGridWeek extends Equatable {
  const YearGridWeek(this.cells);

  final List<YearGridCell> cells;

  @override
  List<Object> get props => [cells];
}

/// A year laid out like GitHub's contribution graph, one column per week.
///
/// This is plain data rather than layout code so the calendar rules, which
/// are easy to get subtly wrong, can be tested without a widget. A year has
/// 53 columns, or 54 for a leap year that starts on a Sunday.
class YearGrid extends Equatable {
  const YearGrid({
    required this.year,
    required this.weeks,
    required this.monthStartColumns,
    required this.todayColumn,
  });

  /// Lays out [year] as of [today], with [checkInDays] filled in.
  ///
  /// [checkInDays] may include days from other years, which are ignored.
  factory YearGrid.build({
    required int year,
    required Set<CalendarDay> checkInDays,
    required CalendarDay today,
  }) {
    final newYearsDay = CalendarDay(year, 1, 1);
    // `weekday` counts from Monday, so this is the Monday on or before
    // 1 January, which can fall in the previous year.
    final firstMonday = newYearsDay.addDays(
      DateTime.monday - newYearsDay.weekday,
    );

    int columnOf(CalendarDay day) =>
        day.daysSince(firstMonday) ~/ DateTime.daysPerWeek;

    YearGridCell cellFor(CalendarDay day) {
      if (day.year != year) {
        return const YearGridCell(state: YearGridCellState.outsideYear);
      }

      final YearGridCellState state;
      if (day.isAfter(today)) {
        state = YearGridCellState.future;
      } else if (checkInDays.contains(day)) {
        state = YearGridCellState.filled;
      } else if (day == today) {
        state = YearGridCellState.today;
      } else {
        state = YearGridCellState.empty;
      }
      return YearGridCell(day: day, state: state);
    }

    final columnCount = columnOf(CalendarDay(year, 12, 31)) + 1;

    return YearGrid(
      year: year,
      weeks: [
        for (var column = 0; column < columnCount; column++)
          YearGridWeek([
            for (var row = 0; row < DateTime.daysPerWeek; row++)
              cellFor(firstMonday.addDays(column * DateTime.daysPerWeek + row)),
          ]),
      ],
      monthStartColumns: [
        for (var month = DateTime.january; month <= DateTime.december; month++)
          columnOf(CalendarDay(year, month, 1)),
      ],
      todayColumn: today.year == year ? columnOf(today) : null,
    );
  }

  final int year;

  /// The columns of the grid, oldest first.
  final List<YearGridWeek> weeks;

  /// The column holding the 1st of each month: index 0 is January, 11 is
  /// December. Month labels are drawn above these columns.
  final List<int> monthStartColumns;

  /// The column holding today, for scrolling it into view. Null if today is
  /// in another year.
  final int? todayColumn;

  @override
  List<Object?> get props => [year, weeks, monthStartColumns, todayColumn];
}
