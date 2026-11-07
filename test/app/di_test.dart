import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/app/di.dart';
import 'package:gym_grid/features/check_in/data/database/app_database.dart';
import 'package:gym_grid/features/check_in/data/local_check_in_repository.dart';
import 'package:gym_grid/features/check_in/data/photo_store.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_photo.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/check_in/domain/repositories/photo_locator.dart';
import 'package:gym_grid/features/check_in/domain/usecases/delete_all_check_ins.dart';
import 'package:gym_grid/features/check_in/domain/usecases/delete_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/get_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/save_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/update_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/watch_check_in.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_history.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_progress.dart';
import 'package:gym_grid/features/settings/presentation/link_opener.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory container;
  late Directory documents;
  late Directory temporary;

  setUp(() async {
    container = await Directory.systemTemp.createTemp('di_test_');
    documents = await Directory(p.join(container.path, 'Documents')).create();
    temporary = await Directory(p.join(container.path, 'tmp')).create();
  });

  tearDown(() async {
    // Also closes the database, through its registered dispose function.
    await getIt.reset();
    await container.delete(recursive: true);
  });

  final packageInfo = PackageInfo(
    appName: 'GymGrid',
    packageName: 'com.ninikurshavishvili.gymgrid',
    version: '1.0.0',
    buildNumber: '1',
  );

  Future<void> register() => registerDependencies(
    database: AppDatabase(NativeDatabase.memory()),
    documentsDirectory: documents,
    temporaryDirectory: temporary,
    packageInfo: packageInfo,
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
      sourcePhotoPaths: [photo.path],
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
      sourcePhotoPaths: [photo.path],
      workoutType: WorkoutType.mobility,
    );

    expect((await getIt<WatchProgress>()().first).checkIns, [saved]);
    expect((await getIt<WatchHistory>()().first).single.checkIns, [saved]);
    expect(await getIt<GetCheckIn>()(saved.date), saved);
    expect(await getIt<WatchCheckIn>()(saved.date).first, saved);

    final edited = await getIt<UpdateCheckIn>()(
      id: saved.id,
      photos: [StoredPhoto(saved.coverPhotoPath)],
      workoutType: WorkoutType.cardio,
      activity: null,
    );
    expect(await getIt<GetCheckIn>()(saved.date), edited);

    await getIt<DeleteCheckIn>()(saved.id);

    expect(await getIt<GetCheckIn>()(saved.date), isNull);
  });

  test('provides the app version and the link opener', () async {
    await register();

    expect(getIt<PackageInfo>(), same(packageInfo));
    expect(getIt<LinkOpener>(), isA<LinkOpener>());
  });

  test('wires deleting all data to the repository and photo store', () async {
    await register();
    final photo = File(p.join(container.path, 'tmp', 'camera.jpg'));
    await photo.create(recursive: true);
    await getIt<SaveCheckIn>()(
      sourcePhotoPaths: [photo.path],
      workoutType: WorkoutType.strength,
    );

    await getIt<DeleteAllCheckIns>()();

    expect(await getIt<CheckInRepository>().watchAll().first, isEmpty);
    expect(Directory(p.join(documents.path, 'photos')).listSync(), isEmpty);
  });

  test('deletes picked photos left over from a form open at the last '
      'launch', () async {
    final leftover = File(p.join(temporary.path, 'picked_photos', 'a.jpg'));
    await leftover.create(recursive: true);
    final unrelated = File(p.join(temporary.path, 'other.tmp'));
    await unrelated.create();

    await register();

    expect(leftover.existsSync(), isFalse);
    expect(unrelated.existsSync(), isTrue);
    expect(
      getIt<PhotoPicker>().folder.path,
      p.join(temporary.path, 'picked_photos'),
    );
  });

  test('deletes photos left over from an unfinished save', () async {
    final orphan = File(p.join(documents.path, 'photos', 'orphan.jpg'));
    await orphan.create(recursive: true);

    await register();

    expect(orphan.existsSync(), isFalse);
  });
}
