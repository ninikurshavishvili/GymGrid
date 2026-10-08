import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/data/database/app_database.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  CheckInsCompanion row({
    String id = 'a',
    CalendarDay? day,
    String? note = 'Leg day',
  }) {
    return CheckInsCompanion.insert(
      id: id,
      day: day ?? CalendarDay(2026, 10, 5),
      photoPath: 'photos/$id.jpg',
      workoutType: WorkoutType.strength,
      note: Value(note),
      createdAt: DateTime(2026, 10, 5, 7, 42, 10, 123),
    );
  }

  test('stores and reads back every column', () async {
    await db.into(db.checkIns).insert(row(id: 'a'));
    await db
        .into(db.checkIns)
        .insert(row(id: 'b', day: CalendarDay(2026, 10, 6), note: null));

    final rows = await (db.select(
      db.checkIns,
    )..orderBy([(t) => OrderingTerm(expression: t.day)])).get();

    expect(rows, [
      CheckInRow(
        id: 'a',
        day: CalendarDay(2026, 10, 5),
        photoPath: 'photos/a.jpg',
        workoutType: WorkoutType.strength,
        note: 'Leg day',
        createdAt: DateTime(2026, 10, 5, 7, 42, 10, 123),
      ),
      CheckInRow(
        id: 'b',
        day: CalendarDay(2026, 10, 6),
        photoPath: 'photos/b.jpg',
        workoutType: WorkoutType.strength,
        createdAt: DateTime(2026, 10, 5, 7, 42, 10, 123),
      ),
    ]);
  });

  // Changing how a column is written to disk would need a migration for
  // existing databases. This test makes any such change deliberate.
  test(
    'writes days, workout types and times in a stable text format',
    () async {
      await db.into(db.checkIns).insert(row());

      final raw = await db
          .customSelect('SELECT day, workout_type, created_at FROM check_ins')
          .getSingle();

      expect(raw.read<String>('day'), '2026-10-05');
      expect(raw.read<String>('workout_type'), 'strength');
      expect(
        raw.read<String>('created_at'),
        startsWith('2026-10-05T07:42:10.123'),
      );
    },
  );

  test('rejects a second check-in for the same day', () async {
    await db.into(db.checkIns).insert(row(id: 'a'));

    await expectLater(
      db.into(db.checkIns).insert(row(id: 'b')),
      throwsA(isA<SqliteException>()),
    );
  });
}
