import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/data/database/converters.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';

void main() {
  group('CalendarDayConverter', () {
    const converter = CalendarDayConverter();

    test('stores a day as yyyy-MM-dd and reads it back', () {
      final day = CalendarDay(2026, 2, 7);

      expect(converter.toSql(day), '2026-02-07');
      expect(converter.fromSql('2026-02-07'), day);
    });

    test('rejects text that is not a day', () {
      expect(() => converter.fromSql('2026-02-30'), throwsFormatException);
    });
  });

  group('PhotoPathsConverter', () {
    const converter = PhotoPathsConverter();

    test('stores paths as a JSON list and reads them back in order', () {
      const paths = ['photos/b.jpg', 'photos/a.jpg'];

      expect(converter.toSql(paths), '["photos/b.jpg","photos/a.jpg"]');
      expect(converter.fromSql(converter.toSql(paths)), paths);
    });

    test('rejects text that is not a list of paths', () {
      expect(() => converter.fromSql('[]'), throwsFormatException);
      expect(() => converter.fromSql('{"a":1}'), throwsFormatException);
      expect(() => converter.fromSql('photos/a.jpg'), throwsFormatException);
    });
  });

  group('WorkoutTypeConverter', () {
    const converter = WorkoutTypeConverter();

    // These strings are saved in users' databases, so changing one needs a
    // migration. This test makes any such change deliberate.
    test('stores each type as fixed text', () {
      expect(
        {for (final type in WorkoutType.values) type: converter.toSql(type)},
        {
          WorkoutType.strength: 'strength',
          WorkoutType.cardio: 'cardio',
          WorkoutType.mobility: 'mobility',
          WorkoutType.other: 'other',
        },
      );
    });

    test('reads back every type', () {
      for (final type in WorkoutType.values) {
        expect(converter.fromSql(converter.toSql(type)), type);
      }
    });

    test('rejects unknown text', () {
      expect(() => converter.fromSql('yoga'), throwsFormatException);
    });
  });

  group('OtherActivityConverter', () {
    const converter = OtherActivityConverter();

    // Stored text, so changing it would need a migration.
    test('stores each activity as fixed text', () {
      expect(OtherActivity.values.map(converter.toSql), [
        'class',
        'sport',
        'walk',
      ]);
    });

    test('reads back every activity', () {
      for (final activity in OtherActivity.values) {
        expect(converter.fromSql(converter.toSql(activity)), activity);
      }
    });

    test('rejects text that is not an activity', () {
      expect(() => converter.fromSql('yoga'), throwsFormatException);
    });
  });
}
