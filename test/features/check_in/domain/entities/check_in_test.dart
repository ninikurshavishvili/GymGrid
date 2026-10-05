import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';

CheckIn _checkIn({
  String id = '1',
  CalendarDay? date,
  String photoPath = 'photos/1.jpg',
  WorkoutType workoutType = WorkoutType.strength,
  String? note = 'Leg day',
  DateTime? createdAt,
}) {
  return CheckIn(
    id: id,
    date: date ?? CalendarDay(2026, 10, 5),
    photoPath: photoPath,
    workoutType: workoutType,
    note: note,
    createdAt: createdAt ?? DateTime(2026, 10, 5, 7, 42),
  );
}

void main() {
  test('check-ins with the same values are equal', () {
    expect(_checkIn(), _checkIn());
  });

  // A Cubit skips emitting a state equal to the current one, so a field
  // missing from `props` would leave the UI showing stale data.
  test('every field takes part in equality', () {
    final variants = {
      'id': _checkIn(id: '2'),
      'date': _checkIn(date: CalendarDay(2026, 10, 4)),
      'photoPath': _checkIn(photoPath: 'photos/2.jpg'),
      'workoutType': _checkIn(workoutType: WorkoutType.cardio),
      'note': _checkIn(note: null),
      'createdAt': _checkIn(createdAt: DateTime(2026, 10, 5, 7, 43)),
    };

    for (final MapEntry(key: field, value: variant) in variants.entries) {
      expect(variant, isNot(_checkIn()), reason: field);
    }
  });
}
