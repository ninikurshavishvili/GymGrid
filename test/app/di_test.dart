import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/app/di.dart';
import 'package:gym_grid/features/check_in/data/database/app_database.dart';
import 'package:gym_grid/features/check_in/data/local_check_in_repository.dart';
import 'package:gym_grid/features/check_in/data/photo_store.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/check_in/domain/repositories/photo_locator.dart';
import 'package:gym_grid/features/check_in/domain/usecases/delete_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/get_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/save_check_in.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_progress.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory container;
  late Directory documents;

  setUp(() async {
    container = await Directory.systemTemp.createTemp('di_test_');
    documents = await Directory(p.join(container.path, 'Documents')).create();
  });

  tearDown(() async {
    // Also closes the database, through its registered dispose function.
    await getIt.reset();
    await container.delete(recursive: true);
  });

  Future<void> register() => registerDependencies(
    database: AppDatabase(NativeDatabase.memory()),
    documentsDirectory: documents,
  );

  test('registers the local repository behind its interface', () async {
    await register();

    expect(getIt<CheckInRepository>(), isA<LocalCheckInRepository>());
  });

  test('wires the save use case to the repository', () async {
    await register();
    final photo = File(p.join(container.path, 'tmp', 'camera.jpg'));
    await photo.create(recursive: true);

    final saved = await getIt<SaveCheckIn>()(
      sourcePhotoPath: photo.path,
      workoutType: WorkoutType.mobility,
    );

    expect(await getIt<CheckInRepository>().findByDate(saved.date), saved);
  });

  test('exposes the photo store as the photo locator', () async {
    await register();

    expect(getIt<PhotoLocator>(), same(getIt<PhotoStore>()));
  });

  test('provides the photo picker', () async {
    await register();

    expect(getIt<PhotoPicker>(), isA<PhotoPicker>());
  });

  test('wires the read and delete use cases to the repository', () async {
    await register();
    final photo = File(p.join(container.path, 'tmp', 'camera.jpg'));
    await photo.create(recursive: true);
    final saved = await getIt<SaveCheckIn>()(
      sourcePhotoPath: photo.path,
      workoutType: WorkoutType.mobility,
    );

    expect((await getIt<WatchProgress>()().first).checkIns, [saved]);
    expect(await getIt<GetCheckIn>()(saved.date), saved);

    await getIt<DeleteCheckIn>()(saved.id);

    expect(await getIt<GetCheckIn>()(saved.date), isNull);
  });

  test('deletes photos left over from an unfinished save', () async {
    final orphan = File(p.join(documents.path, 'photos', 'orphan.jpg'));
    await orphan.create(recursive: true);

    await register();

    expect(orphan.existsSync(), isFalse);
  });
}
