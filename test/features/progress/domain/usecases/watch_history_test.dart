import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/progress/domain/entities/history_month.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_history.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

void main() {
  late _MockCheckInRepository repository;
  late WatchHistory watchHistory;

  final checkIn = CheckIn(
    id: '1',
    date: CalendarDay(2026, 11, 6),
    photoPaths: const ['photos/1.jpg'],
    workoutType: WorkoutType.strength,
    createdAt: DateTime(2026, 11, 6, 7, 42),
  );

  setUp(() {
    repository = _MockCheckInRepository();
    watchHistory = WatchHistory(repository: repository);
  });

  test('emits the months for each change to the check-ins', () async {
    when(() => repository.watchAll()).thenAnswer(
      (_) => Stream.fromIterable([
        const [],
        [checkIn],
      ]),
    );

    await expectLater(
      watchHistory(),
      emitsInOrder([
        isEmpty,
        [
          HistoryMonth(year: 2026, month: 11, checkIns: [checkIn]),
        ],
        emitsDone,
      ]),
    );
  });

  test('passes failures on', () async {
    when(
      () => repository.watchAll(),
    ).thenAnswer((_) => Stream.error(const StorageFailure()));

    await expectLater(watchHistory(), emitsError(isA<StorageFailure>()));
  });
}
