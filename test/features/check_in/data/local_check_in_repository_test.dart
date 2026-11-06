import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/data/database/app_database.dart';
import 'package:gym_grid/features/check_in/data/local_check_in_repository.dart';
import 'package:gym_grid/features/check_in/data/photo_store.dart';
import 'package:gym_grid/features/check_in/data/uuid.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/new_check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:path/path.dart' as p;

void main() {
  // A real in-memory database and real files in a temporary folder that
  // stands in for the app container.
  late Directory container;
  late Directory documents;
  late AppDatabase database;
  late LocalCheckInRepository repository;

  LocalCheckInRepository createRepository(PhotoStore photoStore) {
    return LocalCheckInRepository(
      database: database,
      photoStore: photoStore,
      uuids: UuidGenerator(Random(1)),
    );
  }

  setUp(() async {
    container = await Directory.systemTemp.createTemp('repository_test_');
    documents = await Directory(p.join(container.path, 'Documents')).create();
    database = AppDatabase(NativeDatabase.memory());
    repository = createRepository(PhotoStore(documents));
  });

  tearDown(() async {
    await database.close();
    await container.delete(recursive: true);
  });

  /// Writes a photo to `tmp/`, as the camera does, and returns its path.
  Future<String> cameraPhoto([String name = 'camera.jpg']) async {
    final file = File(p.join(container.path, 'tmp', name));
    await file.create(recursive: true);
    await file.writeAsString(name);
    return file.path;
  }

  Future<CheckIn> save(
    CalendarDay date, {
    String? sourcePhotoPath,
    WorkoutType workoutType = WorkoutType.strength,
    String? note,
  }) async {
    return repository.save(
      NewCheckIn(
        date: date,
        sourcePhotoPath: sourcePhotoPath ?? await cameraPhoto(),
        workoutType: workoutType,
        note: note,
        createdAt: date.toLocalDateTime().add(const Duration(hours: 7)),
      ),
    );
  }

  /// The files in `Documents/photos`, as relative paths.
  Set<String> storedPhotos() {
    final folder = Directory(p.join(documents.path, 'photos'));
    if (!folder.existsSync()) return {};
    return {
      for (final file in folder.listSync())
        p.relative(file.path, from: documents.path),
    };
  }

  final oct4 = CalendarDay(2026, 10, 4);
  final oct5 = CalendarDay(2026, 10, 5);
  final oct6 = CalendarDay(2026, 10, 6);

  group('save', () {
    test('stores the check-in and a copy of its photo', () async {
      final source = await cameraPhoto();

      final saved = await save(
        oct5,
        sourcePhotoPath: source,
        workoutType: WorkoutType.cardio,
        note: 'Intervals',
      );

      expect(saved.date, oct5);
      expect(saved.workoutType, WorkoutType.cardio);
      expect(saved.note, 'Intervals');
      expect(saved.createdAt, DateTime(2026, 10, 5, 7));
      expect(saved.photoPath, 'photos/${saved.id}.jpg');
      expect(storedPhotos(), {saved.photoPath});
      expect(await repository.findByDate(oct5), saved);
      expect(File(source).existsSync(), isTrue);
    });

    test('gives each check-in a new UUID', () async {
      final first = await save(oct4);
      final second = await save(oct5);

      final uuid = RegExp(r'^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$');
      expect(first.id, matches(uuid));
      expect(second.id, matches(uuid));
      expect(first.id, isNot(second.id));
    });

    test('replaces the check-in for the same day, and its photo', () async {
      final first = await save(oct5, note: 'Morning');

      final second = await save(oct5, note: 'Evening');

      expect(second.id, isNot(first.id));
      expect(await repository.findByDate(oct5), second);
      expect(await repository.watchAll().first, [second]);
      expect(storedPhotos(), {second.photoPath});
    });

    test('leaves other days alone', () async {
      final other = await save(oct4);

      await save(oct5);
      await save(oct5);

      expect(await repository.findByDate(oct4), other);
      expect(storedPhotos(), contains(other.photoPath));
    });

    test('keeps the earlier check-in and removes the copy when the database '
        'write fails', () async {
      final earlier = await save(oct5);
      // Makes every insert fail inside the transaction, after the day's
      // earlier row has been deleted.
      await database.customStatement(
        'CREATE TRIGGER fail_inserts BEFORE INSERT ON check_ins '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      final source = await cameraPhoto('retry.jpg');

      await expectLater(
        save(oct5, sourcePhotoPath: source),
        throwsA(isA<StorageFailure>()),
      );

      expect(await repository.findByDate(oct5), earlier);
      expect(storedPhotos(), {earlier.photoPath});
      expect(File(source).existsSync(), isTrue);
    });

    test(
      'fails without storing anything when the source photo is missing',
      () async {
        final missing = p.join(container.path, 'tmp', 'missing.jpg');

        await expectLater(
          save(oct5, sourcePhotoPath: missing),
          throwsA(
            isA<StorageFailure>().having(
              (failure) => failure.cause,
              'cause',
              isA<FileSystemException>(),
            ),
          ),
        );

        expect(await repository.findByDate(oct5), isNull);
        expect(storedPhotos(), isEmpty);
      },
    );

    test('succeeds even if the replaced photo has an invalid path', () async {
      await _insertRowWithInvalidPhotoPath(database);

      final saved = await save(oct5);

      expect(await repository.findByDate(oct5), saved);
    });

    test('succeeds even if the replaced photo cannot be deleted', () async {
      repository = createRepository(_UndeletablePhotoStore(documents));
      final first = await save(oct5);

      final second = await save(oct5);

      expect(await repository.findByDate(oct5), second);
      // Left for the launch cleanup.
      expect(storedPhotos(), {first.photoPath, second.photoPath});
    });
  });

  group('watchAll', () {
    test('emits every check-in, ordered by day', () async {
      final b = await save(oct6);
      final c = await save(oct4);
      final a = await save(oct5);

      expect(await repository.watchAll().first, [c, a, b]);
    });

    test('emits again after each change', () async {
      final checkIns = StreamIterator(repository.watchAll());
      addTearDown(checkIns.cancel);

      expect(await checkIns.moveNext(), isTrue);
      expect(checkIns.current, isEmpty);

      final first = await save(oct5);
      expect(await checkIns.moveNext(), isTrue);
      expect(checkIns.current, [first]);

      final second = await save(oct4);
      expect(await checkIns.moveNext(), isTrue);
      expect(checkIns.current, [second, first]);

      await repository.delete(first.id);
      expect(await checkIns.moveNext(), isTrue);
      expect(checkIns.current, [second]);
    });

    test('emits unreadable data as a StorageFailure', () async {
      await _insertUnreadableRow(database);

      await expectLater(
        repository.watchAll(),
        emitsError(
          isA<StorageFailure>().having(
            (failure) => failure.cause,
            'cause',
            isA<FormatException>(),
          ),
        ),
      );
    });
  });

  group('findByDate', () {
    test('returns null when the day has no check-in', () async {
      await save(oct4);

      expect(await repository.findByDate(oct5), isNull);
    });

    test('throws a StorageFailure for unreadable data', () async {
      await _insertUnreadableRow(database);

      await expectLater(
        repository.findByDate(oct5),
        throwsA(isA<StorageFailure>()),
      );
    });
  });

  group('delete', () {
    test('removes the check-in and its photo', () async {
      final kept = await save(oct4);
      final deleted = await save(oct5);

      await repository.delete(deleted.id);

      expect(await repository.watchAll().first, [kept]);
      expect(storedPhotos(), {kept.photoPath});
    });

    test('does nothing for an unknown id', () async {
      final kept = await save(oct5);

      await repository.delete('unknown');

      expect(await repository.watchAll().first, [kept]);
      expect(storedPhotos(), {kept.photoPath});
    });

    test('succeeds even if the photo cannot be deleted', () async {
      repository = createRepository(_UndeletablePhotoStore(documents));
      final checkIn = await save(oct5);

      await repository.delete(checkIn.id);

      expect(await repository.findByDate(oct5), isNull);
    });

    test('succeeds even if the photo has an invalid path', () async {
      await _insertRowWithInvalidPhotoPath(database);

      await repository.delete('x');

      expect(await repository.findByDate(oct5), isNull);
    });

    test('throws a StorageFailure when the database fails', () async {
      final checkIn = await save(oct5);
      await database.close();

      await expectLater(
        repository.delete(checkIn.id),
        throwsA(isA<StorageFailure>()),
      );
    });
  });

  group('deleteUnreferencedPhotos', () {
    test('deletes only the photos no check-in refers to', () async {
      final kept = await save(oct5);
      final orphan = File(p.join(documents.path, 'photos', 'orphan.jpg'))
        ..writeAsStringSync('left by an interrupted save');

      await repository.deleteUnreferencedPhotos();

      expect(storedPhotos(), {kept.photoPath});
      expect(orphan.existsSync(), isFalse);
    });
  });
}

/// Inserts a row whose workout type no version of the app writes.
Future<void> _insertUnreadableRow(AppDatabase database) {
  return database.customStatement(
    'INSERT INTO check_ins (id, day, photo_path, workout_type, created_at) '
    "VALUES ('x', '2026-10-05', 'photos/x.jpg', 'yoga', "
    "'2026-10-05T07:00:00.000')",
  );
}

/// Inserts a row whose photo path [PhotoStore] rejects, as a corrupted
/// database might hold.
Future<void> _insertRowWithInvalidPhotoPath(AppDatabase database) {
  return database.customStatement(
    'INSERT INTO check_ins (id, day, photo_path, workout_type, created_at) '
    "VALUES ('x', '2026-10-05', '../outside.jpg', 'strength', "
    "'2026-10-05T07:00:00.000')",
  );
}

/// A [PhotoStore] whose deletes fail, as when a file is locked.
class _UndeletablePhotoStore extends PhotoStore {
  const _UndeletablePhotoStore(super.documentsDirectory);

  @override
  Future<void> delete(String photoPath) async {
    throw FileSystemException('Operation not permitted', photoPath);
  }
}
