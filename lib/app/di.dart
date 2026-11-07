import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/date/clock.dart';
import '../core/errors/failure.dart';
import '../features/check_in/data/database/app_database.dart';
import '../features/check_in/data/local_check_in_repository.dart';
import '../features/check_in/data/photo_store.dart';
import '../features/check_in/domain/repositories/check_in_repository.dart';
import '../features/check_in/domain/repositories/photo_locator.dart';
import '../features/check_in/domain/usecases/delete_all_check_ins.dart';
import '../features/check_in/domain/usecases/delete_check_in.dart';
import '../features/check_in/domain/usecases/get_check_in.dart';
import '../features/check_in/domain/usecases/save_check_in.dart';
import '../features/check_in/domain/usecases/update_check_in.dart';
import '../features/check_in/domain/usecases/watch_check_in.dart';
import '../features/check_in/presentation/photo_picker.dart';
import '../features/progress/domain/usecases/watch_history.dart';
import '../features/progress/domain/usecases/watch_progress.dart';
import '../features/progress/domain/usecases/watch_trends.dart';
import '../features/settings/presentation/link_opener.dart';

/// The app's service locator, the composition root for dependencies.
///
/// Only the `app` layer touches [getIt]. Screens receive their Cubits from
/// the router, and Cubits receive use cases through their constructors, so
/// features never depend on the container directly.
final GetIt getIt = GetIt.instance;

/// Opens the app's storage and registers all dependencies. Called once from
/// `main` before `runApp`.
Future<void> configureDependencies() async {
  // Read first, so a failure here leaves no database behind to clean up.
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final temporaryDirectory = await getTemporaryDirectory();
  final packageInfo = await PackageInfo.fromPlatform();

  await registerDependencies(
    database: AppDatabase(
      driftDatabase(
        name: 'gym_grid',
        // Application Support rather than Documents: the database is
        // internal app data, like a Core Data store. drift opens it on a
        // background isolate, so queries never block the UI.
        native: const DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
        ),
      ),
    ),
    documentsDirectory: documentsDirectory,
    temporaryDirectory: temporaryDirectory,
    packageInfo: packageInfo,
  );
}

/// Registers all dependencies around [database], the photos kept in
/// [documentsDirectory], the app's [temporaryDirectory] and its
/// [packageInfo], then deletes photos left over from a check-in the app
/// didn't finish.
///
/// Separate from [configureDependencies] so tests can pass an in-memory
/// database and a temporary folder.
@visibleForTesting
Future<void> registerDependencies({
  required AppDatabase database,
  required Directory documentsDirectory,
  required Directory temporaryDirectory,
  required PackageInfo packageInfo,
}) async {
  final photoStore = PhotoStore(documentsDirectory);
  // On iOS the temporary directory is Library/Caches, which isn't backed
  // up, so photos waiting to be stored never reach a backup.
  final photoPicker = PhotoPicker(
    folder: Directory(p.join(temporaryDirectory.path, 'picked_photos')),
  );
  final repository = LocalCheckInRepository(
    database: database,
    photoStore: photoStore,
  );

  // Nothing can be saving yet, so neither of these can delete a photo that
  // is about to be saved.
  await photoPicker.discardAll();
  try {
    await repository.deleteUnreferencedPhotos();
  } on StorageFailure catch (failure, stackTrace) {
    // Only housekeeping: the app works without it, and the next launch
    // tries again. Reported like any caught error, without crashing.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: failure,
        stack: stackTrace,
        library: 'gym_grid',
        context: ErrorDescription('while deleting unreferenced photos'),
      ),
    );
  }

  getIt
    ..registerSingleton<Clock>(const Clock())
    ..registerSingleton<PackageInfo>(packageInfo)
    ..registerSingleton<AppDatabase>(
      database,
      dispose: (database) => database.close(),
    )
    ..registerSingleton<PhotoStore>(photoStore)
    ..registerSingleton<PhotoLocator>(photoStore)
    ..registerSingleton<CheckInRepository>(repository)
    ..registerSingleton<PhotoPicker>(photoPicker)
    ..registerLazySingleton<LinkOpener>(LinkOpener.new)
    ..registerLazySingleton<SaveCheckIn>(
      () => SaveCheckIn(repository: getIt(), clock: getIt()),
    )
    ..registerLazySingleton<UpdateCheckIn>(
      () => UpdateCheckIn(repository: getIt()),
    )
    ..registerLazySingleton<GetCheckIn>(() => GetCheckIn(repository: getIt()))
    ..registerLazySingleton<WatchCheckIn>(
      () => WatchCheckIn(repository: getIt()),
    )
    ..registerLazySingleton<DeleteCheckIn>(
      () => DeleteCheckIn(repository: getIt()),
    )
    ..registerLazySingleton<DeleteAllCheckIns>(
      () => DeleteAllCheckIns(repository: getIt()),
    )
    ..registerLazySingleton<WatchProgress>(
      () => WatchProgress(repository: getIt(), clock: getIt()),
    )
    ..registerLazySingleton<WatchHistory>(
      () => WatchHistory(repository: getIt()),
    )
    ..registerLazySingleton<WatchTrends>(
      () => WatchTrends(repository: getIt(), clock: getIt()),
    );
}
