import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/check_in/domain/usecases/watch_check_in.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

void main() {
  late _MockCheckInRepository repository;
  late WatchCheckIn watchCheckIn;

  final oct5 = CalendarDay(2026, 10, 5);
  final oct6 = CalendarDay(2026, 10, 6);

  CheckIn checkInOn(CalendarDay day, {String? note}) => CheckIn(
    id: '$day',
    date: day,
    photoPaths: const ['photos/1.jpg'],
    workoutType: WorkoutType.strength,
    note: note,
    createdAt: DateTime(2026, 10, 5, 7, 42),
  );

  setUp(() {
    repository = _MockCheckInRepository();
    watchCheckIn = WatchCheckIn(repository: repository);
  });

  test('emits the day\'s check-in, then each change to it', () async {
    when(() => repository.watchAll()).thenAnswer(
      (_) => Stream.fromIterable([
        [checkInOn(oct5)],
        [checkInOn(oct5, note: 'Edited')],
        const <CheckIn>[],
      ]),
    );

    await expectLater(
      watchCheckIn(oct5),
      emitsInOrder([
        checkInOn(oct5),
        checkInOn(oct5, note: 'Edited'),
        null,
        emitsDone,
      ]),
    );
  });

  test('stays quiet when only other days change', () async {
    when(() => repository.watchAll()).thenAnswer(
      (_) => Stream.fromIterable([
        [checkInOn(oct5)],
        [checkInOn(oct5), checkInOn(oct6)],
      ]),
    );

    await expectLater(
      watchCheckIn(oct5),
      emitsInOrder([checkInOn(oct5), emitsDone]),
    );
  });

  test('passes a storage failure on to the subscriber', () async {
    when(
      () => repository.watchAll(),
    ).thenAnswer((_) => Stream.error(const StorageFailure()));

    await expectLater(watchCheckIn(oct5), emitsError(isA<StorageFailure>()));
  });
}
