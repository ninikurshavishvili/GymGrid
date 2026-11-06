import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/progress/domain/entities/progress.dart';
import 'package:gym_grid/features/progress/domain/entities/year_grid.dart';

void main() {
  const outside = YearGridCell(state: YearGridCellState.outsideYear);

  YearGrid gridFor(
    int year, {
    Set<CalendarDay> checkInDays = const {},
    CalendarDay? today,
  }) {
    return YearGrid.build(
      year: year,
      checkInDays: checkInDays,
      today: today ?? CalendarDay(year, 6, 15),
    );
  }

  Iterable<YearGridCell> cellsOf(YearGrid grid) =>
      grid.weeks.expand((week) => week.cells);

  /// Every cell that isn't padding, in grid order.
  List<CalendarDay> daysOf(YearGrid grid) => [
    for (final cell in cellsOf(grid)) ?cell.day,
  ];

  YearGridCell cellOf(YearGrid grid, CalendarDay day) =>
      cellsOf(grid).singleWhere((cell) => cell.day == day);

  Iterable<YearGridCell> cellsIn(YearGrid grid, YearGridCellState state) =>
      cellsOf(grid).where((cell) => cell.state == state);

  // Years that cover each way a year can start and end, including both
  // leap year shapes.
  const years = [2018, 2023, 2024, 2026, 2027, 2028, 2029, 2040];

  group('layout', () {
    test('every week has seven cells, Monday first', () {
      for (final year in years) {
        for (final week in gridFor(year).weeks) {
          expect(week.cells, hasLength(7), reason: '$year');
          for (final (row, cell) in week.cells.indexed) {
            if (cell.day case final day?) {
              expect(day.weekday, row + 1, reason: '$day');
            }
          }
        }
      }
    });

    test('holds every day of the year once, in order', () {
      for (final year in years) {
        final days = daysOf(gridFor(year));
        final isLeap = year % 4 == 0;

        expect(days, hasLength(isLeap ? 366 : 365), reason: '$year');
        expect(days.first, CalendarDay(year, 1, 1));
        expect(days.last, CalendarDay(year, 12, 31));
        for (var i = 1; i < days.length; i++) {
          expect(days[i].daysSince(days[i - 1]), 1, reason: '${days[i]}');
        }
      }
    });

    test('a year starting on a Monday has no padding before 1 January', () {
      final firstWeek = gridFor(2029).weeks.first;

      expect(firstWeek.cells.first.day, CalendarDay(2029, 1, 1));
      expect(firstWeek.cells.contains(outside), isFalse);
    });

    test('a year starting on a Sunday puts 1 January last in its column', () {
      final cells = gridFor(2023).weeks.first.cells;

      expect(cells.take(6), everyElement(outside));
      expect(cells.last.day, CalendarDay(2023, 1, 1));
    });

    test('a leap year includes 29 February', () {
      final grid = gridFor(2028);

      expect(daysOf(grid), contains(CalendarDay(2028, 2, 29)));
      // 2028 starts on a Saturday.
      final cells = grid.weeks.first.cells;
      expect(cells.take(5), everyElement(outside));
      expect(cells[5].day, CalendarDay(2028, 1, 1));
      expect(cells[6].day, CalendarDay(2028, 1, 2));
    });

    test('pads the week after 31 December', () {
      // 31 December 2026 is a Thursday.
      final cells = gridFor(2026).weeks.last.cells;

      expect(cells[3].day, CalendarDay(2026, 12, 31));
      expect(cells.skip(4), everyElement(outside));
    });

    test('has 53 columns, or 54 for a leap year starting on a Sunday', () {
      for (final year in years) {
        expect(
          gridFor(year).weeks,
          hasLength(year == 2040 ? 54 : 53),
          reason: '$year',
        );
      }
    });
  });

  group('cell states', () {
    final today = CalendarDay(2026, 10, 5);

    test('days before today are empty and days after it are future', () {
      final grid = gridFor(2026, today: today);

      expect(cellOf(grid, today.addDays(-1)).state, YearGridCellState.empty);
      expect(cellOf(grid, today.addDays(1)).state, YearGridCellState.future);
      expect(cellOf(grid, CalendarDay(2026, 1, 1)).state, isNot(outside.state));
    });

    test('today stands out until the user checks in', () {
      expect(
        cellOf(gridFor(2026, today: today), today).state,
        YearGridCellState.today,
      );
      expect(
        cellOf(gridFor(2026, today: today, checkInDays: {today}), today).state,
        YearGridCellState.filled,
      );
    });

    test('only days with a check-in are filled', () {
      final yesterday = today.addDays(-1);

      final grid = gridFor(2026, today: today, checkInDays: {yesterday});

      expect(cellsIn(grid, YearGridCellState.filled).map((cell) => cell.day), [
        yesterday,
      ]);
    });

    test('with today on 1 January, every other day is in the future', () {
      final grid = gridFor(2027, today: CalendarDay(2027, 1, 1));

      expect(cellsIn(grid, YearGridCellState.today), hasLength(1));
      expect(cellsIn(grid, YearGridCellState.empty), isEmpty);
      expect(cellsIn(grid, YearGridCellState.future), hasLength(364));
    });

    test('with today on 31 December, no day is in the future', () {
      final grid = gridFor(2026, today: CalendarDay(2026, 12, 31));

      expect(cellsIn(grid, YearGridCellState.today), hasLength(1));
      expect(cellsIn(grid, YearGridCellState.future), isEmpty);
      expect(cellsIn(grid, YearGridCellState.empty), hasLength(364));
    });

    test('ignores check-ins from other years, even in a padded week', () {
      // 31 December 2025 shares a column with 1 January 2026.
      final grid = gridFor(
        2026,
        today: today,
        checkInDays: {CalendarDay(2025, 12, 31), CalendarDay(2027, 1, 1)},
      );

      expect(grid.weeks.first.cells[2], outside);
      expect(cellsIn(grid, YearGridCellState.filled), isEmpty);
    });

    test('does not fill a check-in after today, as after the clock moves '
        'back', () {
      final tomorrow = today.addDays(1);

      final grid = gridFor(2026, today: today, checkInDays: {tomorrow});

      expect(cellOf(grid, tomorrow).state, YearGridCellState.future);
      expect(cellsIn(grid, YearGridCellState.filled), isEmpty);
    });

    test('fills as many cells as the check-in count on the home screen', () {
      final days = [
        CalendarDay(2025, 12, 31), // Last year.
        CalendarDay(2026, 1, 1),
        today,
        today.addDays(1), // After today.
      ];
      final checkIns = [
        for (final day in days)
          CheckIn(
            id: '$day',
            date: day,
            photoPath: 'photos/$day.jpg',
            workoutType: WorkoutType.strength,
            createdAt: day.toLocalDateTime(),
          ),
      ];

      final grid = gridFor(2026, today: today, checkInDays: days.toSet());

      expect(
        cellsIn(grid, YearGridCellState.filled),
        hasLength(Progress.from(checkIns, today: today).checkInCountThisYear),
      );
    });
  });

  group('monthStartColumns', () {
    test('gives the column of the 1st of each month', () {
      expect(gridFor(2026).monthStartColumns, [
        0,
        4,
        8,
        13,
        17,
        22,
        26,
        30,
        35,
        39,
        43,
        48,
      ]);
    });

    test('always points at a column holding the 1st', () {
      for (final year in years) {
        final grid = gridFor(year);

        expect(grid.monthStartColumns, hasLength(12));
        for (final (index, column) in grid.monthStartColumns.indexed) {
          final firstOfMonth = CalendarDay(year, index + 1, 1);
          expect(
            grid.weeks[column].cells.map((cell) => cell.day),
            contains(firstOfMonth),
            reason: '$firstOfMonth',
          );
        }
      }
    });
  });

  group('todayColumn', () {
    test('is the column holding today', () {
      final grid = gridFor(2026, today: CalendarDay(2026, 11, 6));

      expect(grid.todayColumn, 44);
      expect(
        grid.weeks[44].cells.map((cell) => cell.day),
        contains(CalendarDay(2026, 11, 6)),
      );
    });

    test('is the last column on 31 December', () {
      final grid = gridFor(2026, today: CalendarDay(2026, 12, 31));

      expect(grid.todayColumn, grid.weeks.length - 1);
    });

    test('is null when today is in another year', () {
      expect(gridFor(2025, today: CalendarDay(2026, 1, 1)).todayColumn, isNull);
    });
  });
}
