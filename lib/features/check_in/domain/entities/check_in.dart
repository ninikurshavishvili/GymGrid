import 'package:equatable/equatable.dart';

import '../../../../core/date/calendar_day.dart';
import 'workout_type.dart';

/// A day's gym check-in: a photo, the kind of workout and an optional note.
///
/// There is at most one check-in per [date].
class CheckIn extends Equatable {
  const CheckIn({
    required this.id,
    required this.date,
    required this.photoPath,
    required this.workoutType,
    required this.createdAt,
    this.note,
  });

  /// The longest note allowed, in characters as the user sees them.
  ///
  /// The check-in form enforces this as the user types; its text field
  /// counts an emoji as one character. Dart's core library can only count
  /// UTF-16 code units or code points, which would disagree with the field,
  /// so the domain doesn't check the limit again.
  static const int maxNoteLength = 280;

  /// Assigned by the repository when the check-in is saved.
  final String id;

  /// The day this check-in counts for.
  final CalendarDay date;

  /// The photo's path relative to the app's documents directory.
  ///
  /// Relative because on iOS the absolute path of the app's container
  /// changes across app updates and reinstalls, so a stored absolute path
  /// would go stale.
  final String photoPath;

  final WorkoutType workoutType;

  /// Null when the user left the note empty; never blank.
  final String? note;

  /// When the check-in was saved, shown as the check-in time.
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    date,
    photoPath,
    workoutType,
    note,
    createdAt,
  ];
}
