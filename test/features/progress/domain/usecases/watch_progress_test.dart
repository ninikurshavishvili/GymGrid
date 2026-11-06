import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/date/clock.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/progress/domain/entities/progress.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_progress.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

void main() {
  late _MockCheckInRepository repository;

  final oct5 = CalendarDay(2026, 10, 5);
  final oct6 = CalendarDay(2026, 10, 6);
  final checkIn = CheckIn(
    id: '1',
    date: oct5,
    photoPath: 'photos/1.jpg',
    workoutType: WorkoutType.strength,
    createdAt: DateTime(2026, 10, 5, 7, 42),
  );

  setUp(() => repository = _MockCheckInRepository());

  test('emits progress as of today for each change to the check-ins', () async {
    when(() => repository.watchAll()).thenAnswer(
      (_) => Stream.fromIterable([
        const [],
        [checkIn],
      ]),
    );
    final watchProgress = WatchProgress(
      repository: repository,
      clock: Clock(() => DateTime(2026, 10, 5, 20)),
    );

    await expectLater(
      watchProgress(),
      emitsInOrder([
        Progress.from(const [], today: oct5),
        Progress.from([checkIn], today: oct5),
        emitsDone,
      ]),
    );
  });

  test('reads the clock for each emission, so a change after midnight counts '
      'as the new day', () async {
    var now = DateTime(2026, 10, 5, 23, 59);
    final checkIns = StreamController<List<CheckIn>>();
    addTearDown(checkIns.close);
    when(() => repository.watchAll()).thenAnswer((_) => checkIns.stream);
    final progress = StreamIterator(
      WatchProgress(repository: repository, clock: Clock(() => now))(),
    );
    addTearDown(progress.cancel);

    checkIns.add([checkIn]);
    expect(await progress.moveNext(), isTrue);
    expect(progress.current.today, oct5);
    expect(progress.current.todaysCheckIn, checkIn);

    now = DateTime(2026, 10, 6, 0, 1);
    checkIns.add([checkIn]);
    expect(await progress.moveNext(), isTrue);
    expect(progress.current.today, oct6);
    expect(progress.current.todaysCheckIn, isNull);
  });

  test('passes a storage failure on to the subscriber', () async {
    when(
      () => repository.watchAll(),
    ).thenAnswer((_) => Stream.error(const StorageFailure()));
    final watchProgress = WatchProgress(
      repository: repository,
      clock: Clock(() => DateTime(2026, 10, 5)),
    );

    await expectLater(watchProgress(), emitsError(isA<StorageFailure>()));
  });
}
