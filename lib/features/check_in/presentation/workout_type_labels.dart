import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../domain/entities/check_in.dart';
import '../domain/entities/other_activity.dart';
import '../domain/entities/workout_type.dart';

/// How each [WorkoutType] appears on screen. Wording and icons belong to the
/// presentation layer, so the domain enum stays free of them.
extension WorkoutTypeLabel on WorkoutType {
  String get label => switch (this) {
    WorkoutType.strength => 'Strength',
    WorkoutType.cardio => 'Cardio',
    WorkoutType.mobility => 'Mobility',
    WorkoutType.other => 'Other',
  };

  IconData get icon => switch (this) {
    WorkoutType.strength => Icons.fitness_center_rounded,
    WorkoutType.cardio => Icons.directions_run_rounded,
    WorkoutType.mobility => Icons.self_improvement_rounded,
    WorkoutType.other => CupertinoIcons.ellipsis,
  };

  /// The name of a check-in of this type when nothing more specific was
  /// chosen. "Other" names a choice in the form, not a workout.
  String get checkInTitle => switch (this) {
    WorkoutType.other => 'Workout',
    _ => label,
  };

  /// The icon beside [checkInTitle]. The form's "more" ellipsis would look
  /// like a menu there.
  IconData get checkInIcon => switch (this) {
    WorkoutType.other => Icons.sports_gymnastics_rounded,
    _ => icon,
  };

  /// What the note field asks once this type is chosen.
  String get notePrompt => switch (this) {
    WorkoutType.strength => 'What did you train? (optional)',
    WorkoutType.cardio => 'How far, or how long? (optional)',
    WorkoutType.mobility => 'What did you work on? (optional)',
    WorkoutType.other => 'What did you do? (optional)',
  };

  /// Common notes for this type, offered as one-tap additions.
  ///
  /// None for Other, which offers [OtherActivity] choices instead.
  List<String> get noteSuggestions => switch (this) {
    WorkoutType.strength => const ['Push', 'Pull', 'Legs', 'Full body', 'PR'],
    WorkoutType.cardio => const ['Run', 'Bike', 'Swim', 'Row', 'Intervals'],
    WorkoutType.mobility => const ['Stretching', 'Yoga', 'Foam rolling'],
    WorkoutType.other => const [],
  };
}

/// How each [OtherActivity] appears on screen.
extension OtherActivityLabel on OtherActivity {
  String get label => switch (this) {
    OtherActivity.groupClass => 'Class',
    OtherActivity.sport => 'Sport',
    OtherActivity.walk => 'Walk',
  };

  IconData get icon => switch (this) {
    OtherActivity.groupClass => Icons.groups_rounded,
    OtherActivity.sport => Icons.sports_basketball_rounded,
    OtherActivity.walk => Icons.directions_walk_rounded,
  };
}

/// What a check-in is called on screen: its activity if the user chose one,
/// otherwise its workout type.
extension CheckInTitle on CheckIn {
  String get title => activity?.label ?? workoutType.checkInTitle;

  IconData get titleIcon => activity?.icon ?? workoutType.checkInIcon;
}
