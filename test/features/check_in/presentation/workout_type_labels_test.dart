import 'package:flutter_test/flutter_test.dart';
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

  test('every workout type offers note suggestions', () {
    for (final type in WorkoutType.values) {
      expect(type.noteSuggestions, isNotEmpty, reason: '$type');
    }
  });
}
