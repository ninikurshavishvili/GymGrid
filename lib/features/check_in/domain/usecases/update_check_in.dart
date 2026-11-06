import '../../../../core/errors/failure.dart';
import '../entities/check_in.dart';
import '../entities/check_in_edit.dart';
import '../entities/check_in_photo.dart';
import '../entities/workout_type.dart';
import '../repositories/check_in_repository.dart';

/// Changes an existing check-in. Its day and check-in time stay as they were.
class UpdateCheckIn {
  const UpdateCheckIn({required CheckInRepository repository})
    : _repository = repository;

  final CheckInRepository _repository;

  /// Gives the check-in with [id] these [photos], [workoutType] and [note].
  ///
  /// A blank [note] is stored as no note. Throws a [Failure] if the change
  /// can't be stored.
  Future<CheckIn> call({
    required String id,
    required List<CheckInPhoto> photos,
    required WorkoutType workoutType,
    String? note,
  }) {
    return _repository.update(
      CheckInEdit(
        id: id,
        photos: photos,
        workoutType: workoutType,
        note: CheckIn.cleanNote(note),
      ),
    );
  }
}
