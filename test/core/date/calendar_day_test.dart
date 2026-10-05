import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';

void main() {
  group('construction', () {
    test('keeps the year, month and day', () {
      final day = CalendarDay(2026, 10, 5);

      expect((day.year, day.month, day.day), (2026, 10, 5));
    });

    test('rolls out-of-range values over like DateTime', () {
      expect(CalendarDay(2026, 12, 32), CalendarDay(2027, 1, 1));
      expect(CalendarDay(2026, 3, 0), CalendarDay(2026, 2, 28));
    });

    test('fromDateTime drops the time of day', () {
      expect(
        CalendarDay.fromDateTime(DateTime(2026, 10, 5, 23, 59, 59)),
        CalendarDay(2026, 10, 5),
      );
      expect(
        CalendarDay.fromDateTime(DateTime(2026, 10, 5)),
        CalendarDay(2026, 10, 5),
      );
    });
  });

  group('equality and ordering', () {
    test('the same day is one set element whatever its time', () {
      final days = {
        CalendarDay(2026, 10, 5),
        CalendarDay.fromDateTime(DateTime(2026, 10, 5, 7, 42)),
      };

      expect(days, hasLength(1));
    });

    test('sorts chronologically', () {
      final days = [
        CalendarDay(2027, 1, 1),
        CalendarDay(2026, 2, 7),
        CalendarDay(2026, 12, 31),
      ]..sort();

      expect(days, [
        CalendarDay(2026, 2, 7),
        CalendarDay(2026, 12, 31),
        CalendarDay(2027, 1, 1),
      ]);
    });

    test('isBefore and isAfter compare days', () {
      final earlier = CalendarDay(2026, 12, 31);
      final later = CalendarDay(2027, 1, 1);

      expect(earlier.isBefore(later), isTrue);
      expect(later.isAfter(earlier), isTrue);
      expect(earlier.isBefore(earlier), isFalse);
      expect(earlier.isAfter(earlier), isFalse);
    });
  });

  group('arithmetic', () {
    test('addDays crosses month and year ends in both directions', () {
      expect(CalendarDay(2026, 1, 31).addDays(1), CalendarDay(2026, 2, 1));
      expect(CalendarDay(2026, 12, 31).addDays(1), CalendarDay(2027, 1, 1));
      expect(CalendarDay(2027, 1, 1).addDays(-1), CalendarDay(2026, 12, 31));
    });

    test('addDays includes 29 February only in leap years', () {
      expect(CalendarDay(2028, 2, 28).addDays(1), CalendarDay(2028, 2, 29));
      expect(CalendarDay(2027, 2, 28).addDays(1), CalendarDay(2027, 3, 1));
    });

    test('daysSince counts across year boundaries', () {
      expect(CalendarDay(2027, 1, 1).daysSince(CalendarDay(2026, 12, 31)), 1);
      expect(
        CalendarDay(2026, 1, 1).daysSince(CalendarDay(2026, 12, 31)),
        -364,
      );
      expect(CalendarDay(2029, 1, 1).daysSince(CalendarDay(2028, 1, 1)), 366);
    });

    // In US and European time zones, local midnights on these dates are 23
    // or 25 hours apart. An implementation built on local DateTimes fails
    // here when run in such a zone, e.g. `TZ=Europe/London flutter test`.
    test('is unaffected by daylight saving changes', () {
      final changes = [
        (CalendarDay(2026, 3, 8), 'US clocks go forward'),
        (CalendarDay(2026, 3, 29), 'EU clocks go forward'),
        (CalendarDay(2026, 10, 25), 'EU clocks go back'),
        (CalendarDay(2026, 11, 1), 'US clocks go back'),
      ];

      for (final (day, reason) in changes) {
        final next = day.addDays(1);
        expect(next.day, day.day + 1, reason: reason);
        expect(next.daysSince(day), 1, reason: reason);
      }
    });
  });

  test('weekday runs from Monday (1) to Sunday (7)', () {
    expect(CalendarDay(2026, 10, 5).weekday, DateTime.monday);
    expect(CalendarDay(2026, 10, 11).weekday, DateTime.sunday);
  });

  test('toLocalDateTime is local midnight on the same date', () {
    final dateTime = CalendarDay(2026, 10, 5).toLocalDateTime();

    expect(dateTime, DateTime(2026, 10, 5));
    expect(dateTime.isUtc, isFalse);
  });

  group('ISO 8601', () {
    test('formats as zero-padded yyyy-MM-dd', () {
      expect(CalendarDay(2026, 2, 7).toIso8601String(), '2026-02-07');
      expect(CalendarDay(2026, 2, 7).toString(), '2026-02-07');
    });

    test('tryParse reads what toIso8601String writes', () {
      final day = CalendarDay(2028, 2, 29);

      expect(CalendarDay.tryParse(day.toIso8601String()), day);
    });

    for (final input in [
      '2026-2-7',
      '2026-02-30',
      '2026-13-01',
      '2026-02-07T10:00',
      ' 2026-02-07',
      '',
    ]) {
      test('tryParse rejects "$input"', () {
        expect(CalendarDay.tryParse(input), isNull);
      });
    }
  });
}
