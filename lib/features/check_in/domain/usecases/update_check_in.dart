import '../../../../core/errors/failure.dart';
import '../entities/check_in.dart';
import '../entities/check_in_edit.dart';
import '../entities/check_in_photo.dart';
import '../entities/other_activity.dart';
import '../entities/rating.dart';
import '../entities/workout_type.dart';
import '../repositories/check_in_repository.dart';

/// Changes an existing check-in. Its day and check-in time stay as they were.
class UpdateCheckIn {
  const UpdateCheckIn({required CheckInRepository repository})
    : _repository = repository;

  final CheckInRepository _repository;

  /// Gives the check-in with [id] these [photos], [workoutType], [activity],
  /// [note], [effort] and [energy].
  ///
  /// [activity] is kept only for an Other workout, and a blank [note] is
  /// stored as no note. [activity], [effort] and [energy] are required,
  /// though they can be null, so a caller changing something else can't
  /// clear them by leaving them out. Throws a [Failure] if the change can't
  /// be stored.
  Future<CheckIn> call({
    required String id,
    required List<CheckInPhoto> photos,
    required WorkoutType workoutType,
    required OtherActivity? activity,
    required Rating? effort,
    required Rating? energy,
    String? note,
  }) {
    return _repository.update(
      CheckInEdit(
        id: id,
        photos: photos,
        workoutType: workoutType,
        activity: CheckIn.activityFor(workoutType, activity),
        note: CheckIn.cleanNote(note),
        effort: effort,
        energy: energy,
      ),
    );
  }
}
