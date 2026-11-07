import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';

CheckIn _checkIn({
  String id = '1',
  CalendarDay? date,
  List<String> photoPaths = const ['photos/1.jpg'],
  WorkoutType workoutType = WorkoutType.strength,
  OtherActivity? activity,
  String? note = 'Leg day',
  Rating? effort,
  Rating? energy,
  DateTime? createdAt,
}) {
  return CheckIn(
    id: id,
    date: date ?? CalendarDay(2026, 10, 5),
    photoPaths: photoPaths,
    workoutType: workoutType,
    activity: activity,
    note: note,
    effort: effort,
    energy: energy,
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
      'photoPaths': _checkIn(photoPaths: const ['photos/2.jpg']),
      'workoutType': _checkIn(workoutType: WorkoutType.cardio),
      'note': _checkIn(note: null),
      'effort': _checkIn(effort: Rating.high),
      'energy': _checkIn(energy: Rating.low),
      'createdAt': _checkIn(createdAt: DateTime(2026, 10, 5, 7, 43)),
    };

    for (final MapEntry(key: field, value: variant) in variants.entries) {
      expect(variant, isNot(_checkIn()), reason: field);
    }
  });

  test('the activity takes part in equality', () {
    expect(
      _checkIn(workoutType: WorkoutType.other, activity: OtherActivity.walk),
      isNot(_checkIn(workoutType: WorkoutType.other)),
    );
  });

  test('only an Other workout can have an activity', () {
    expect(
      () => _checkIn(activity: OtherActivity.walk),
      throwsA(isA<AssertionError>()),
    );
  });

  group('activityFor', () {
    test('keeps the activity of an Other workout', () {
      expect(
        CheckIn.activityFor(WorkoutType.other, OtherActivity.sport),
        OtherActivity.sport,
      );
    });

    test('drops it for every other type', () {
      for (final type in WorkoutType.values) {
        if (type == WorkoutType.other) continue;
        expect(
          CheckIn.activityFor(type, OtherActivity.sport),
          isNull,
          reason: '$type',
        );
      }
    });
  });

  test('the first photo is the cover', () {
    final checkIn = _checkIn(
      photoPaths: const ['photos/a.jpg', 'photos/b.jpg'],
    );

    expect(checkIn.coverPhotoPath, 'photos/a.jpg');
  });

  group('cleanNote', () {
    test('trims a note', () {
      expect(CheckIn.cleanNote('  Deadlift PR\n'), 'Deadlift PR');
    });

    test('turns a missing or blank note into no note', () {
      for (final note in [null, '', '   ', ' \n\t ']) {
        expect(CheckIn.cleanNote(note), isNull, reason: 'note: "$note"');
      }
    });
  });
}
