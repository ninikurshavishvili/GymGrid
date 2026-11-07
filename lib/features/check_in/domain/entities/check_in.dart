import 'package:equatable/equatable.dart';

import '../../../../core/date/calendar_day.dart';
import 'other_activity.dart';
import 'rating.dart';
import 'workout_type.dart';

/// A day's gym check-in: its photos, the kind of workout, and optionally a
/// note and how hard it was and how much energy the user had.
///
/// There is at most one check-in per [date].
class CheckIn extends Equatable {
  const CheckIn({
    required this.id,
    required this.date,
    required this.photoPaths,
    required this.workoutType,
    required this.createdAt,
    this.activity,
    this.note,
    this.effort,
    this.energy,
  }) : assert(
         activity == null || workoutType == WorkoutType.other,
         'Only an Other workout has an activity',
       );

  /// The longest note allowed, in characters as the user sees them.
  ///
  /// The check-in form enforces this as the user types; its text field
  /// counts an emoji as one character. Dart's core library can only count
  /// UTF-16 code units or code points, which would disagree with the field,
  /// so the domain doesn't check the limit again.
  static const int maxNoteLength = 280;

  /// The most photos one check-in can hold.
  static const int maxPhotos = 6;

  /// Assigned by the repository when the check-in is saved.
  final String id;

  /// The day this check-in counts for.
  final CalendarDay date;

  /// The photos' paths relative to the app's documents directory, cover
  /// first. Never empty.
  ///
  /// Relative because on iOS the absolute path of the app's container
  /// changes across app updates and reinstalls, so a stored absolute path
  /// would go stale.
  final List<String> photoPaths;

  final WorkoutType workoutType;

  /// What an Other workout was, or null if the user didn't say. Always null
  /// for the other workout types.
  final OtherActivity? activity;

  /// Null when the user left the note empty; never blank.
  final String? note;

  /// How hard the workout was, or null if the user didn't say.
  final Rating? effort;

  /// How much energy the user had, or null if they didn't say.
  final Rating? energy;

  /// When the check-in was saved, shown as the check-in time.
  final DateTime createdAt;

  /// The photo that stands for this check-in in lists.
  String get coverPhotoPath => photoPaths.first;

  /// [activity] if [workoutType] can have one, otherwise null, so switching
  /// away from Other drops an activity chosen for it.
  static OtherActivity? activityFor(
    WorkoutType workoutType,
    OtherActivity? activity,
  ) => workoutType == WorkoutType.other ? activity : null;

  /// [note] trimmed, or null if that leaves nothing, as stored notes are.
  static String? cleanNote(String? note) {
    final trimmed = note?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
    id,
    date,
    photoPaths,
    workoutType,
    activity,
    note,
    effort,
    energy,
    createdAt,
  ];
}
