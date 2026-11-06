import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

import '../core/date/clock.dart';
import '../core/errors/failure.dart';
import '../features/check_in/data/database/app_database.dart';
import '../features/check_in/data/local_check_in_repository.dart';
import '../features/check_in/data/photo_store.dart';
import '../features/check_in/domain/repositories/check_in_repository.dart';
import '../features/check_in/domain/repositories/photo_locator.dart';
import '../features/check_in/domain/usecases/delete_check_in.dart';
import '../features/check_in/domain/usecases/get_check_in.dart';
import '../features/check_in/domain/usecases/save_check_in.dart';
import '../features/check_in/domain/usecases/update_check_in.dart';
import '../features/check_in/domain/usecases/watch_check_in.dart';
import '../features/check_in/presentation/photo_picker.dart';
import '../features/progress/domain/usecases/watch_progress.dart';

/// The app's service locator, the composition root for dependencies.
///
/// Only the `app` layer touches [getIt]. Screens receive their Cubits from
/// the router, and Cubits receive use cases through their constructors, so
/// features never depend on the container directly.
final GetIt getIt = GetIt.instance;

/// Opens the app's storage and registers all dependencies. Called once from
/// `main` before `runApp`.
Future<void> configureDependencies() async {
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
    documentsDirectory: await getApplicationDocumentsDirectory(),
  );
}

/// Registers all dependencies around [database] and the photos kept in
/// [documentsDirectory], then deletes photos left over from a save the app
/// didn't finish.
///
/// Separate from [configureDependencies] so tests can pass an in-memory
/// database and a temporary folder.
@visibleForTesting
Future<void> registerDependencies({
  required AppDatabase database,
  required Directory documentsDirectory,
}) async {
  final photoStore = PhotoStore(documentsDirectory);
  final repository = LocalCheckInRepository(
    database: database,
    photoStore: photoStore,
  );

  // Nothing can be saving yet, so this can't delete a photo that is about
  // to be saved.
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
    ..registerSingleton<AppDatabase>(
      database,
      dispose: (database) => database.close(),
    )
    ..registerSingleton<PhotoStore>(photoStore)
    ..registerSingleton<PhotoLocator>(photoStore)
    ..registerSingleton<CheckInRepository>(repository)
    ..registerLazySingleton<PhotoPicker>(PhotoPicker.new)
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
    ..registerLazySingleton<WatchProgress>(
      () => WatchProgress(repository: getIt(), clock: getIt()),
    );
}
