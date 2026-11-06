import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/date/calendar_day.dart';
import '../../../core/errors/failure.dart';
import '../domain/entities/check_in.dart';
import '../domain/entities/new_check_in.dart';
import '../domain/repositories/check_in_repository.dart';
import 'database/app_database.dart';
import 'photo_store.dart';
import 'uuid.dart';

/// Stores check-ins on the device: rows in SQLite, photos as files.
///
/// The two stores are updated in an order that keeps them consistent
/// without a shared transaction: a photo is copied before any row refers to
/// it and deleted only after no row does. If the app stops in between, the
/// worst left behind is a photo nothing refers to, which
/// [deleteUnreferencedPhotos] removes at the next launch. A row never
/// points at a missing or half-written file.
///
/// Every error, including those on the [watchAll] stream, is rethrown as a
/// [StorageFailure] that keeps the original as its cause.
class LocalCheckInRepository implements CheckInRepository {
  LocalCheckInRepository({
    required AppDatabase database,
    required PhotoStore photoStore,
    UuidGenerator? uuids,
  }) : _database = database,
       _photoStore = photoStore,
       _uuids = uuids ?? UuidGenerator();

  final AppDatabase _database;
  final PhotoStore _photoStore;
  final UuidGenerator _uuids;

  $CheckInsTable get _checkIns => _database.checkIns;

  @override
  Stream<List<CheckIn>> watchAll() {
    final query = _database.select(_checkIns)
      ..orderBy([(t) => OrderingTerm.asc(t.day)]);

    return query
        .map(_toCheckIn)
        .watch()
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.addError(StorageFailure(cause: error), stackTrace),
          ),
        );
  }

  @override
  Future<CheckIn?> findByDate(CalendarDay date) => _guard(() {
    final query = _database.select(_checkIns)
      ..where((t) => t.day.equalsValue(date));
    return query.map(_toCheckIn).getSingleOrNull();
  });

  @override
  Future<CheckIn> save(NewCheckIn checkIn) => _guard(() async {
    final id = _uuids.v4();

    // 1. Copy the photo before any row refers to it.
    final photoPath = await _photoStore.save(checkIn.sourcePhotoPath, id: id);

    // 2. Swap the rows in one transaction, so a failure leaves the day's
    // earlier check-in in place rather than deleting it.
    final ({CheckInRow saved, List<CheckInRow> replaced}) rows;
    try {
      rows = await _database.transaction(() async {
        final replaced = await (_database.delete(
          _checkIns,
        )..where((t) => t.day.equalsValue(checkIn.date))).goAndReturn();
        final saved = await _database
            .into(_checkIns)
            .insertReturning(
              CheckInsCompanion.insert(
                id: id,
                day: checkIn.date,
                photoPath: photoPath,
                workoutType: checkIn.workoutType,
                note: Value(checkIn.note),
                createdAt: checkIn.createdAt,
              ),
            );
        return (saved: saved, replaced: replaced);
      });
    } catch (_) {
      // No row refers to the copy, so remove it. The source is untouched,
      // so the save can be retried.
      await _tryDeletePhoto(photoPath);
      rethrow;
    }

    // 3. No row refers to the replaced photo any more.
    for (final row in rows.replaced) {
      await _tryDeletePhoto(row.photoPath);
    }

    return _toCheckIn(rows.saved);
  });

  @override
  Future<void> delete(String id) => _guard(() async {
    final deleted = await (_database.delete(
      _checkIns,
    )..where((t) => t.id.equals(id))).goAndReturn();

    for (final row in deleted) {
      await _tryDeletePhoto(row.photoPath);
    }
  });

  /// Deletes every photo that no check-in refers to.
  ///
  /// Call it at launch, before anything can save a check-in: a save in
  /// progress has a photo that no row refers to yet.
  Future<void> deleteUnreferencedPhotos() => _guard(() async {
    final referenced = await _database
        .select(_checkIns)
        .map((row) => row.photoPath)
        .get();
    await _photoStore.deleteUnreferenced(referenced.toSet());
  });

  /// Deletes a photo that no row refers to any more.
  ///
  /// The check-in change has already succeeded by then, so a failure here
  /// isn't reported: the file is left for [deleteUnreferencedPhotos].
  Future<void> _tryDeletePhoto(String photoPath) async {
    try {
      await _photoStore.delete(photoPath);
    } on FileSystemException {
      // Removed at the next launch instead.
    } on ArgumentError {
      // A path the store rejects, say from a corrupted row, names no file
      // to delete. Its photo, if any, is removed at the next launch too.
    }
  }

  /// Runs [action], rethrowing anything it throws as a [StorageFailure].
  ///
  /// [Error.throwWithStackTrace] keeps the original stack trace, which
  /// points at the code that actually failed.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(StorageFailure(cause: error), stackTrace);
    }
  }

  static CheckIn _toCheckIn(CheckInRow row) => CheckIn(
    id: row.id,
    date: row.day,
    photoPath: row.photoPath,
    workoutType: row.workoutType,
    note: row.note,
    createdAt: row.createdAt,
  );
}
