import '../domain/entities/workout_type.dart';

/// Display names for [WorkoutType]. Wording belongs to the presentation
/// layer, so the domain enum stays free of it.
extension WorkoutTypeLabel on WorkoutType {
  String get label => switch (this) {
    WorkoutType.strength => 'Strength',
    WorkoutType.cardio => 'Cardio',
    WorkoutType.mobility => 'Mobility',
    WorkoutType.other => 'Other',
  };
}
