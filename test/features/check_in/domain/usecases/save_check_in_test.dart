import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/date/clock.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/new_check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/check_in/domain/usecases/save_check_in.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

void main() {
  late _MockCheckInRepository repository;

  setUpAll(() {
    // mocktail needs a value of each custom type used with `any()`.
    registerFallbackValue(
      NewCheckIn(
        date: CalendarDay(2000, 1, 1),
        sourcePhotoPath: '',
        workoutType: WorkoutType.other,
        createdAt: DateTime(2000),
      ),
    );
  });

  setUp(() {
    repository = _MockCheckInRepository();
    // Stores whatever it's given, as the real repository does, adding an id
    // and a permanent photo path.
    when(() => repository.save(any())).thenAnswer((invocation) async {
      final checkIn = invocation.positionalArguments.single as NewCheckIn;
      return CheckIn(
        id: '1',
        date: checkIn.date,
        photoPath: 'photos/1.jpg',
        workoutType: checkIn.workoutType,
        note: checkIn.note,
        createdAt: checkIn.createdAt,
      );
    });
  });

  SaveCheckIn saveCheckInAt(DateTime now) {
    return SaveCheckIn(repository: repository, clock: Clock(() => now));
  }

  NewCheckIn savedCheckIn() {
    return verify(() => repository.save(captureAny())).captured.single
        as NewCheckIn;
  }

  test('stores the photo, type and note, stamped with the current day and '
      'time', () async {
    final now = DateTime(2026, 10, 5, 7, 42);

    await saveCheckInAt(now)(
      sourcePhotoPath: '/tmp/camera.jpg',
      workoutType: WorkoutType.cardio,
      note: 'Intervals',
    );

    expect(
      savedCheckIn(),
      NewCheckIn(
        date: CalendarDay(2026, 10, 5),
        sourcePhotoPath: '/tmp/camera.jpg',
        workoutType: WorkoutType.cardio,
        note: 'Intervals',
        createdAt: now,
      ),
    );
  });

  test('a check-in in the last second of a day counts for that day', () async {
    await saveCheckInAt(DateTime(2026, 12, 31, 23, 59, 59, 999))(
      sourcePhotoPath: '/tmp/camera.jpg',
      workoutType: WorkoutType.strength,
    );

    expect(savedCheckIn().date, CalendarDay(2026, 12, 31));
  });

  test('returns the stored check-in', () async {
    final checkIn = await saveCheckInAt(DateTime(2026, 10, 5, 7, 42))(
      sourcePhotoPath: '/tmp/camera.jpg',
      workoutType: WorkoutType.mobility,
    );

    expect(checkIn.id, '1');
    expect(checkIn.photoPath, 'photos/1.jpg');
  });

  test('trims the note', () async {
    await saveCheckInAt(DateTime(2026, 10, 5))(
      sourcePhotoPath: '/tmp/camera.jpg',
      workoutType: WorkoutType.strength,
      note: '  Deadlift PR\n',
    );

    expect(savedCheckIn().note, 'Deadlift PR');
  });

  test('stores a missing or blank note as no note', () async {
    for (final note in [null, '', '   ', ' \n\t ']) {
      await saveCheckInAt(DateTime(2026, 10, 5))(
        sourcePhotoPath: '/tmp/camera.jpg',
        workoutType: WorkoutType.strength,
        note: note,
      );

      expect(savedCheckIn().note, isNull, reason: 'note: "$note"');
    }
  });

  test('passes a storage failure on to the caller', () async {
    when(
      () => repository.save(any()),
    ).thenAnswer((_) async => throw const StorageFailure());

    await expectLater(
      saveCheckInAt(DateTime(2026, 10, 5))(
        sourcePhotoPath: '/tmp/camera.jpg',
        workoutType: WorkoutType.strength,
      ),
      throwsA(isA<StorageFailure>()),
    );
  });
}
