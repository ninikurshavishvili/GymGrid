import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/data/database/app_database.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
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
      photoPaths: ['photos/$id.jpg', 'photos/$id-2.jpg'],
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

    expect(rows, hasLength(2));
    final first = rows.first;
    expect(first.id, 'a');
    expect(first.day, CalendarDay(2026, 10, 5));
    expect(first.photoPaths, ['photos/a.jpg', 'photos/a-2.jpg']);
    expect(first.workoutType, WorkoutType.strength);
    expect(first.note, 'Leg day');
    expect(first.createdAt, DateTime(2026, 10, 5, 7, 42, 10, 123));
    expect(rows.last.id, 'b');
    expect(rows.last.note, isNull);
  });

  // Changing how a column is written to disk would need a migration for
  // existing databases. This test makes any such change deliberate.
  test(
    'writes days, workout types and times in a stable text format',
    () async {
      await db.into(db.checkIns).insert(row());

      final raw = await db
          .customSelect(
            'SELECT day, photo_paths, workout_type, created_at FROM check_ins',
          )
          .getSingle();

      expect(raw.read<String>('day'), '2026-10-05');
      expect(
        raw.read<String>('photo_paths'),
        '["photos/a.jpg","photos/a-2.jpg"]',
      );
      expect(raw.read<String>('workout_type'), 'strength');
      expect(
        raw.read<String>('created_at'),
        startsWith('2026-10-05T07:42:10.123'),
      );
    },
  );

  test('stores an activity as fixed text and reads it back', () async {
    await db
        .into(db.checkIns)
        .insert(
          row().copyWith(
            workoutType: const Value(WorkoutType.other),
            activity: const Value(OtherActivity.groupClass),
          ),
        );

    final raw = await db
        .customSelect('SELECT activity FROM check_ins')
        .getSingle();
    expect(raw.read<String>('activity'), 'class');
    expect(
      (await db.select(db.checkIns).getSingle()).activity,
      OtherActivity.groupClass,
    );
  });

  test('rejects a second check-in for the same day', () async {
    await db.into(db.checkIns).insert(row(id: 'a'));

    await expectLater(
      db.into(db.checkIns).insert(row(id: 'b')),
      throwsA(isA<SqliteException>()),
    );
  });

  group('upgrading from version 1, which stored one photo per check-in', () {
    late AppDatabase upgraded;

    setUp(() {
      upgraded = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw
              ..execute(
                'CREATE TABLE "check_ins" ("id" TEXT NOT NULL, '
                '"day" TEXT NOT NULL UNIQUE, "photo_path" TEXT NOT NULL, '
                '"workout_type" TEXT NOT NULL, "note" TEXT NULL, '
                '"created_at" TEXT NOT NULL, PRIMARY KEY ("id"));',
              )
              ..execute(
                "INSERT INTO check_ins VALUES ('a', '2026-10-05', "
                "'photos/a.jpg', 'cardio', 'Intervals', "
                "'2026-10-05T07:42:00.000000 +04:00')",
              )
              ..execute(
                "INSERT INTO check_ins VALUES ('b', '2026-10-06', "
                "'photos/b.jpg', 'strength', NULL, "
                "'2026-10-06T07:42:00.000000 +04:00')",
              )
              ..execute('PRAGMA user_version = 1');
          },
        ),
      );
    });

    tearDown(() => upgraded.close());

    test('keeps every check-in, with its photo in the new list', () async {
      final rows = await upgraded.select(upgraded.checkIns).get();

      expect(rows, hasLength(2));
      expect(rows.first.photoPaths, ['photos/a.jpg']);
      expect(rows.first.workoutType, WorkoutType.cardio);
      expect(rows.first.note, 'Intervals');
      expect(rows.last.photoPaths, ['photos/b.jpg']);
      expect(rows.last.note, isNull);
    });

    test('still allows only one check-in a day', () async {
      await expectLater(
        upgraded
            .into(upgraded.checkIns)
            .insert(
              CheckInsCompanion.insert(
                id: 'c',
                day: CalendarDay(2026, 10, 5),
                photoPaths: const ['photos/c.jpg'],
                workoutType: WorkoutType.other,
                createdAt: DateTime(2026, 10, 5),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('removes the old column and adds the ones since, empty', () async {
      final columns = await upgraded
          .customSelect('PRAGMA table_info(check_ins)')
          .get();

      expect(
        columns.map((column) => column.read<String>('name')),
        unorderedEquals([
          'id',
          'day',
          'photo_paths',
          'workout_type',
          'activity',
          'note',
          'created_at',
        ]),
      );
      final rows = await upgraded.select(upgraded.checkIns).get();
      expect(rows.map((row) => row.activity), [null, null]);
    });
  });

  group('upgrading from version 2, which had no activity', () {
    late AppDatabase upgraded;

    setUp(() {
      upgraded = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw
              ..execute(
                'CREATE TABLE "check_ins" ("id" TEXT NOT NULL, '
                '"day" TEXT NOT NULL UNIQUE, "photo_paths" TEXT NOT NULL, '
                '"workout_type" TEXT NOT NULL, "note" TEXT NULL, '
                '"created_at" TEXT NOT NULL, PRIMARY KEY ("id"));',
              )
              ..execute(
                "INSERT INTO check_ins VALUES ('a', '2026-11-06', "
                '\'["photos/a.jpg","photos/a-2.jpg"]\', \'other\', '
                "'Sport, Walk, Class', '2026-11-06T14:19:00.000000 +04:00')",
              )
              ..execute('PRAGMA user_version = 2');
          },
        ),
      );
    });

    tearDown(() => upgraded.close());

    test('keeps every check-in as it was, with no activity', () async {
      final row = await upgraded.select(upgraded.checkIns).getSingle();

      expect(row.photoPaths, ['photos/a.jpg', 'photos/a-2.jpg']);
      expect(row.workoutType, WorkoutType.other);
      expect(row.note, 'Sport, Walk, Class');
      expect(row.activity, isNull);
    });

    test('can then store an activity', () async {
      await (upgraded.update(upgraded.checkIns)..where((t) => t.id.equals('a')))
          .write(const CheckInsCompanion(activity: Value(OtherActivity.sport)));

      final row = await upgraded.select(upgraded.checkIns).getSingle();
      expect(row.activity, OtherActivity.sport);
    });
  });
}
