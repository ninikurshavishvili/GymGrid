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
import 'package:gym_grid/features/check_in/domain/entities/check_in_edit.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_photo.dart';
import 'package:gym_grid/features/check_in/domain/entities/new_check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:path/path.dart' as p;

/// A photo stored under its own UUID.
final _storedPhoto = RegExp(r'^photos/[0-9a-f]{8}-[0-9a-f-]{27}\.\w+$');

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
    OtherActivity? activity,
    String? note,
  }) async {
    return repository.save(
      NewCheckIn(
        date: date,
        sourcePhotoPaths: [sourcePhotoPath ?? await cameraPhoto()],
        workoutType: workoutType,
        activity: activity,
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

  /// What the stored photo at [photoPath] contains. Test photos hold their
  /// own file name.
  String contentsOf(String photoPath) =>
      File(p.join(documents.path, photoPath)).readAsStringSync();

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
      expect(saved.photoPaths, hasLength(1));
      expect(saved.coverPhotoPath, matches(_storedPhoto));
      expect(storedPhotos(), {saved.coverPhotoPath});
      expect(await repository.findByDate(oct5), saved);
      expect(File(source).existsSync(), isTrue);
    });

    test('stores the activity of an Other workout', () async {
      final saved = await save(
        oct5,
        workoutType: WorkoutType.other,
        activity: OtherActivity.walk,
      );

      expect(saved.activity, OtherActivity.walk);
      expect(await repository.findByDate(oct5), saved);
    });

    test('stores several photos in order, the first as the cover', () async {
      final saved = await repository.save(
        NewCheckIn(
          date: oct5,
          sourcePhotoPaths: [
            await cameraPhoto('first.jpg'),
            await cameraPhoto('second.png'),
          ],
          workoutType: WorkoutType.strength,
          createdAt: DateTime(2026, 10, 5, 7),
        ),
      );

      expect(saved.photoPaths, hasLength(2));
      expect(saved.photoPaths, everyElement(matches(_storedPhoto)));
      expect(storedPhotos(), saved.photoPaths.toSet());
      expect(contentsOf(saved.photoPaths.first), 'first.jpg');
      expect(contentsOf(saved.photoPaths.last), 'second.png');
      expect(await repository.findByDate(oct5), saved);
    });

    test(
      'removes the copies already made when a later photo is missing',
      () async {
        final first = await cameraPhoto('first.jpg');
        final missing = p.join(container.path, 'tmp', 'missing.jpg');

        await expectLater(
          repository.save(
            NewCheckIn(
              date: oct5,
              sourcePhotoPaths: [first, missing],
              workoutType: WorkoutType.strength,
              createdAt: DateTime(2026, 10, 5, 7),
            ),
          ),
          throwsA(isA<StorageFailure>()),
        );

        expect(await repository.findByDate(oct5), isNull);
        expect(storedPhotos(), isEmpty);
      },
    );

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
      expect(storedPhotos(), {second.coverPhotoPath});
    });

    test('leaves other days alone', () async {
      final other = await save(oct4);

      await save(oct5);
      await save(oct5);

      expect(await repository.findByDate(oct4), other);
      expect(storedPhotos(), contains(other.coverPhotoPath));
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
      expect(storedPhotos(), {earlier.coverPhotoPath});
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
      expect(storedPhotos(), {first.coverPhotoPath, second.coverPhotoPath});
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

  group('update', () {
    test('changes the workout type and note, keeping the rest', () async {
      final checkIn = await save(oct5, note: 'Morning');

      final updated = await repository.update(
        CheckInEdit(
          id: checkIn.id,
          photos: [StoredPhoto(checkIn.coverPhotoPath)],
          workoutType: WorkoutType.cardio,
          note: 'Evening',
        ),
      );

      expect(updated.id, checkIn.id);
      expect(updated.date, checkIn.date);
      expect(updated.createdAt, checkIn.createdAt);
      expect(updated.photoPaths, checkIn.photoPaths);
      expect(updated.workoutType, WorkoutType.cardio);
      expect(updated.note, 'Evening');
      expect(await repository.findByDate(oct5), updated);
    });

    test('sets, changes and clears the activity', () async {
      final checkIn = await save(oct5, workoutType: WorkoutType.other);

      Future<CheckIn> edit(WorkoutType workoutType, OtherActivity? activity) =>
          repository.update(
            CheckInEdit(
              id: checkIn.id,
              photos: [StoredPhoto(checkIn.coverPhotoPath)],
              workoutType: workoutType,
              activity: activity,
            ),
          );

      expect(
        (await edit(WorkoutType.other, OtherActivity.sport)).activity,
        OtherActivity.sport,
      );
      expect(
        (await edit(WorkoutType.other, OtherActivity.groupClass)).activity,
        OtherActivity.groupClass,
      );
      expect((await edit(WorkoutType.cardio, null)).activity, isNull);
      expect((await repository.findByDate(oct5))?.activity, isNull);
    });

    test('can remove the note', () async {
      final checkIn = await save(oct5, note: 'Morning');

      final updated = await repository.update(
        CheckInEdit(
          id: checkIn.id,
          photos: [StoredPhoto(checkIn.coverPhotoPath)],
          workoutType: checkIn.workoutType,
        ),
      );

      expect(updated.note, isNull);
    });

    test('adds a picked photo after the stored ones', () async {
      final checkIn = await save(oct5);

      final updated = await repository.update(
        CheckInEdit(
          id: checkIn.id,
          photos: [
            StoredPhoto(checkIn.coverPhotoPath),
            PickedPhoto(await cameraPhoto('added.jpg')),
          ],
          workoutType: checkIn.workoutType,
        ),
      );

      expect(updated.photoPaths, hasLength(2));
      expect(updated.coverPhotoPath, checkIn.coverPhotoPath);
      expect(contentsOf(updated.photoPaths.last), 'added.jpg');
      expect(storedPhotos(), updated.photoPaths.toSet());
    });

    test('keeps the order given, so a new photo can come first', () async {
      final checkIn = await save(oct5);

      final updated = await repository.update(
        CheckInEdit(
          id: checkIn.id,
          photos: [
            PickedPhoto(await cameraPhoto('new-cover.jpg')),
            StoredPhoto(checkIn.coverPhotoPath),
          ],
          workoutType: checkIn.workoutType,
        ),
      );

      expect(contentsOf(updated.coverPhotoPath), 'new-cover.jpg');
      expect(updated.photoPaths.last, checkIn.coverPhotoPath);
    });

    test('deletes a stored photo the edit leaves out', () async {
      final checkIn = await save(oct5);
      final withTwo = await repository.update(
        CheckInEdit(
          id: checkIn.id,
          photos: [
            StoredPhoto(checkIn.coverPhotoPath),
            PickedPhoto(await cameraPhoto('added.jpg')),
          ],
          workoutType: checkIn.workoutType,
        ),
      );

      final updated = await repository.update(
        CheckInEdit(
          id: checkIn.id,
          photos: [StoredPhoto(withTwo.photoPaths.last)],
          workoutType: checkIn.workoutType,
        ),
      );

      expect(updated.photoPaths, [withTwo.photoPaths.last]);
      expect(storedPhotos(), {withTwo.photoPaths.last});
    });

    test('emits the change to anyone watching', () async {
      final checkIn = await save(oct5);
      final checkIns = StreamIterator(repository.watchAll());
      addTearDown(checkIns.cancel);
      expect(await checkIns.moveNext(), isTrue);

      final updated = await repository.update(
        CheckInEdit(
          id: checkIn.id,
          photos: [StoredPhoto(checkIn.coverPhotoPath)],
          workoutType: WorkoutType.mobility,
        ),
      );

      expect(await checkIns.moveNext(), isTrue);
      expect(checkIns.current, [updated]);
    });

    test('fails for an unknown id and removes the copies it made', () async {
      await expectLater(
        repository.update(
          CheckInEdit(
            id: 'unknown',
            photos: [PickedPhoto(await cameraPhoto())],
            workoutType: WorkoutType.other,
          ),
        ),
        throwsA(isA<StorageFailure>()),
      );

      expect(storedPhotos(), isEmpty);
    });

    test('changes nothing when a picked photo is missing', () async {
      final checkIn = await save(oct5);
      final missing = p.join(container.path, 'tmp', 'missing.jpg');

      await expectLater(
        repository.update(
          CheckInEdit(
            id: checkIn.id,
            photos: [PickedPhoto(missing)],
            workoutType: WorkoutType.other,
          ),
        ),
        throwsA(isA<StorageFailure>()),
      );

      expect(await repository.findByDate(oct5), checkIn);
      expect(storedPhotos(), checkIn.photoPaths.toSet());
    });

    test('keeps every photo when the database write fails', () async {
      final checkIn = await save(oct5);
      await database.customStatement(
        'CREATE TRIGGER fail_updates BEFORE UPDATE ON check_ins '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      await expectLater(
        repository.update(
          CheckInEdit(
            id: checkIn.id,
            // Leaves out the stored photo, which must survive the failure.
            photos: [PickedPhoto(await cameraPhoto('added.jpg'))],
            workoutType: WorkoutType.other,
          ),
        ),
        throwsA(isA<StorageFailure>()),
      );

      expect(await repository.findByDate(oct5), checkIn);
      expect(storedPhotos(), checkIn.photoPaths.toSet());
    });

    test('succeeds even if a removed photo cannot be deleted', () async {
      repository = createRepository(_UndeletablePhotoStore(documents));
      final checkIn = await save(oct5);

      final updated = await repository.update(
        CheckInEdit(
          id: checkIn.id,
          photos: [PickedPhoto(await cameraPhoto('new.jpg'))],
          workoutType: checkIn.workoutType,
        ),
      );

      expect(await repository.findByDate(oct5), updated);
      // Left for the launch cleanup.
      expect(storedPhotos(), hasLength(2));
    });
  });

  group('delete', () {
    test('removes every photo of the check-in', () async {
      final saved = await repository.save(
        NewCheckIn(
          date: oct5,
          sourcePhotoPaths: [
            await cameraPhoto('first.jpg'),
            await cameraPhoto('second.jpg'),
          ],
          workoutType: WorkoutType.strength,
          createdAt: DateTime(2026, 10, 5, 7),
        ),
      );

      await repository.delete(saved.id);

      expect(storedPhotos(), isEmpty);
    });

    test('removes the check-in and its photo', () async {
      final kept = await save(oct4);
      final deleted = await save(oct5);

      await repository.delete(deleted.id);

      expect(await repository.watchAll().first, [kept]);
      expect(storedPhotos(), {kept.coverPhotoPath});
    });

    test('does nothing for an unknown id', () async {
      final kept = await save(oct5);

      await repository.delete('unknown');

      expect(await repository.watchAll().first, [kept]);
      expect(storedPhotos(), {kept.coverPhotoPath});
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

  group('deleteAll', () {
    test('removes every check-in and every photo', () async {
      await save(oct4);
      await save(oct5);
      await save(oct6, sourcePhotoPath: await cameraPhoto('other.jpg'));
      expect(storedPhotos(), hasLength(3));

      await repository.deleteAll();

      expect(await repository.watchAll().first, isEmpty);
      expect(storedPhotos(), isEmpty);
    });

    test('also removes photos that no check-in refers to', () async {
      final orphan = File(p.join(documents.path, 'photos', 'orphan.jpg'));
      await orphan.create(recursive: true);

      await repository.deleteAll();

      expect(orphan.existsSync(), isFalse);
    });

    test('does nothing when there is nothing to delete', () async {
      await repository.deleteAll();

      expect(await repository.watchAll().first, isEmpty);
    });

    test('lets anyone watching know', () async {
      await save(oct5);
      final emissions = repository.watchAll();

      final expectation = expectLater(
        emissions,
        emitsInOrder([hasLength(1), isEmpty]),
      );
      await Future<void>.delayed(Duration.zero);
      await repository.deleteAll();

      await expectation;
    });

    test('reports photos it cannot delete, and trying again finishes the '
        'job', () async {
      await save(oct5);
      repository = createRepository(_UncleanablePhotoStore(documents));

      await expectLater(repository.deleteAll(), throwsA(isA<StorageFailure>()));
      // The rows are gone already, so nothing refers to the photo left.
      expect(await repository.findByDate(oct5), isNull);
      expect(storedPhotos(), hasLength(1));

      repository = createRepository(PhotoStore(documents));
      await repository.deleteAll();
      expect(storedPhotos(), isEmpty);
    });

    test('throws a StorageFailure when the database fails, and keeps the '
        'photos', () async {
      await save(oct5);
      await database.close();

      await expectLater(repository.deleteAll(), throwsA(isA<StorageFailure>()));
      expect(storedPhotos(), hasLength(1));
    });
  });

  group('deleteUnreferencedPhotos', () {
    test('keeps every photo of a check-in, not only its cover', () async {
      final saved = await repository.save(
        NewCheckIn(
          date: oct5,
          sourcePhotoPaths: [
            await cameraPhoto('first.jpg'),
            await cameraPhoto('second.jpg'),
          ],
          workoutType: WorkoutType.strength,
          createdAt: DateTime(2026, 10, 5, 7),
        ),
      );

      await repository.deleteUnreferencedPhotos();

      expect(storedPhotos(), saved.photoPaths.toSet());
    });

    test('deletes only the photos no check-in refers to', () async {
      final kept = await save(oct5);
      final orphan = File(p.join(documents.path, 'photos', 'orphan.jpg'))
        ..writeAsStringSync('left by an interrupted save');

      await repository.deleteUnreferencedPhotos();

      expect(storedPhotos(), {kept.coverPhotoPath});
      expect(orphan.existsSync(), isFalse);
    });
  });
}

/// Inserts a row whose workout type no version of the app writes.
Future<void> _insertUnreadableRow(AppDatabase database) {
  return database.customStatement(
    'INSERT INTO check_ins (id, day, photo_paths, workout_type, created_at) '
    "VALUES ('x', '2026-10-05', '[\"photos/x.jpg\"]', 'yoga', "
    "'2026-10-05T07:00:00.000')",
  );
}

/// Inserts a row whose photo path [PhotoStore] rejects, as a corrupted
/// database might hold.
Future<void> _insertRowWithInvalidPhotoPath(AppDatabase database) {
  return database.customStatement(
    'INSERT INTO check_ins (id, day, photo_paths, workout_type, created_at) '
    "VALUES ('x', '2026-10-05', '[\"../outside.jpg\"]', 'strength', "
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

/// A [PhotoStore] that can't clear out its folder, as when a file is locked.
class _UncleanablePhotoStore extends PhotoStore {
  const _UncleanablePhotoStore(super.documentsDirectory);

  @override
  Future<void> deleteUnreferenced(Set<String> keep) async {
    throw const FileSystemException('Operation not permitted');
  }
}
