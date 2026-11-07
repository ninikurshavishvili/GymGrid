import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/presentation/workout_type_labels.dart';

void main() {
  test('every workout type has a label', () {
    expect(WorkoutType.values.map((type) => type.label), [
      'Strength',
      'Cardio',
      'Mobility',
      'Other',
    ]);
  });

  test('every workout type has its own prompt and icon', () {
    const types = WorkoutType.values;

    expect(types.map((type) => type.notePrompt).toSet(), hasLength(4));
    expect(types.map((type) => type.icon).toSet(), hasLength(4));
  });

  test('every workout type but Other offers note suggestions', () {
    for (final type in WorkoutType.values) {
      if (type == WorkoutType.other) continue;
      expect(type.noteSuggestions, isNotEmpty, reason: '$type');
    }
  });

  test('Other offers activities instead of note suggestions', () {
    expect(WorkoutType.other.noteSuggestions, isEmpty);
    expect(OtherActivity.values.map((activity) => activity.label), [
      'Class',
      'Sport',
      'Walk',
    ]);
    expect(
      OtherActivity.values.map((activity) => activity.icon).toSet(),
      hasLength(3),
    );
  });

  group('a check-in is called', () {
    CheckIn checkIn(WorkoutType workoutType, {OtherActivity? activity}) =>
        CheckIn(
          id: '1',
          date: CalendarDay(2026, 11, 7),
          photoPaths: const ['photos/1.jpg'],
          workoutType: workoutType,
          activity: activity,
          createdAt: DateTime(2026, 11, 7, 14, 19),
        );

    test('by its workout type', () {
      final strength = checkIn(WorkoutType.strength);

      expect(strength.title, 'Strength');
      expect(strength.titleIcon, WorkoutType.strength.icon);
    });

    test('by its activity, for an Other workout', () {
      final sport = checkIn(WorkoutType.other, activity: OtherActivity.sport);

      expect(sport.title, 'Sport');
      expect(sport.titleIcon, OtherActivity.sport.icon);
    });

    test('"Workout" for an Other workout without an activity, with its own '
        'icon rather than the form\'s ellipsis', () {
      final other = checkIn(WorkoutType.other);

      expect(other.title, 'Workout');
      expect(other.titleIcon, isNot(WorkoutType.other.icon));
    });
  });
}
