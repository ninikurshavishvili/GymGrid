import 'package:equatable/equatable.dart';

import 'check_in_photo.dart';
import 'workout_type.dart';

/// The new contents of an existing check-in, passed to
/// `CheckInRepository.update`.
class CheckInEdit extends Equatable {
  const CheckInEdit({
    required this.id,
    required this.photos,
    required this.workoutType,
    this.note,
  });

  final String id;

  /// Every photo the check-in should have afterwards, cover first. Stored
  /// photos left out of this list are deleted.
  final List<CheckInPhoto> photos;

  final WorkoutType workoutType;
  final String? note;

  @override
  List<Object?> get props => [id, photos, workoutType, note];
}
