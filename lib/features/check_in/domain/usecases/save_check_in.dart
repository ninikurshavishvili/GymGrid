import '../../../../core/date/calendar_day.dart';
import '../../../../core/date/clock.dart';
import '../../../../core/errors/failure.dart';
import '../entities/check_in.dart';
import '../entities/new_check_in.dart';
import '../entities/workout_type.dart';
import '../repositories/check_in_repository.dart';

/// Checks in for today, replacing any earlier check-in today.
///
/// The day and time come from [Clock], not the caller, so a check-in is
/// always for the day it was saved. Called like a function
/// (`saveCheckIn(...)`), Dart's counterpart of Swift's `callAsFunction`.
class SaveCheckIn {
  const SaveCheckIn({
    required CheckInRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final CheckInRepository _repository;
  final Clock _clock;

  /// Stores the photo at [sourcePhotoPath] with [workoutType] and [note].
  ///
  /// A blank [note] is stored as no note. Throws a [Failure] if the
  /// check-in can't be stored.
  Future<CheckIn> call({
    required String sourcePhotoPath,
    required WorkoutType workoutType,
    String? note,
  }) async {
    // Read the clock once so the day and time can't straddle midnight.
    final now = _clock.now();
    final trimmedNote = note?.trim();

    return _repository.save(
      NewCheckIn(
        date: CalendarDay.fromDateTime(now),
        sourcePhotoPath: sourcePhotoPath,
        workoutType: workoutType,
        note: trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
        createdAt: now,
      ),
    );
  }
}
