import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

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

  /// What the note field asks once this type is chosen.
  String get notePrompt => switch (this) {
    WorkoutType.strength => 'What did you train? (optional)',
    WorkoutType.cardio => 'How far, or how long? (optional)',
    WorkoutType.mobility => 'What did you work on? (optional)',
    WorkoutType.other => 'What did you do? (optional)',
  };

  /// Common notes for this type, offered as one-tap additions.
  List<String> get noteSuggestions => switch (this) {
    WorkoutType.strength => const ['Push', 'Pull', 'Legs', 'Full body', 'PR'],
    WorkoutType.cardio => const ['Run', 'Bike', 'Swim', 'Row', 'Intervals'],
    WorkoutType.mobility => const ['Stretching', 'Yoga', 'Foam rolling'],
    WorkoutType.other => const ['Class', 'Sport', 'Walk'],
  };
}
