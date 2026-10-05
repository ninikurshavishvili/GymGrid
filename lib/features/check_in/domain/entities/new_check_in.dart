import 'package:equatable/equatable.dart';

import '../../../../core/date/calendar_day.dart';
import 'workout_type.dart';

/// A check-in that hasn't been stored yet, passed to
/// `CheckInRepository.save`.
///
/// It has no id yet, and its photo is [sourcePhotoPath]: an absolute path
/// to a file such as the camera's temporary photo, which the repository
/// copies into permanent storage.
class NewCheckIn extends Equatable {
  const NewCheckIn({
    required this.date,
    required this.sourcePhotoPath,
    required this.workoutType,
    required this.createdAt,
    this.note,
  });

  final CalendarDay date;
  final String sourcePhotoPath;
  final WorkoutType workoutType;
  final String? note;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    date,
    sourcePhotoPath,
    workoutType,
    note,
    createdAt,
  ];
}
