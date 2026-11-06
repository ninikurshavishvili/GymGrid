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
}
