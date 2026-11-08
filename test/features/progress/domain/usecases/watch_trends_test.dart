import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/date/clock.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/progress/domain/entities/trends.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_trends.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

void main() {
  late _MockCheckInRepository repository;

  final nov7 = CalendarDay(2026, 11, 7);
  final rated = CheckIn(
    id: '1',
    date: nov7,
    photoPaths: const ['photos/1.jpg'],
    workoutType: WorkoutType.strength,
    effort: Rating.high,
    createdAt: DateTime(2026, 11, 7, 7, 42),
  );

  setUp(() => repository = _MockCheckInRepository());

  WatchTrends watchTrends() => WatchTrends(
    repository: repository,
    clock: Clock(() => DateTime(2026, 11, 7, 20)),
  );

  test('emits the trends for the range, as of today, for each change to the '
      'check-ins', () async {
    when(() => repository.watchAll()).thenAnswer(
      (_) => Stream.fromIterable([
        const [],
        [rated],
      ]),
    );

    await expectLater(
      watchTrends()(TrendRange.year),
      emitsInOrder([
        Trends.from(const [], range: TrendRange.year, today: nov7),
        Trends.from([rated], range: TrendRange.year, today: nov7),
        emitsDone,
      ]),
    );
  });

  test('passes storage failures on', () async {
    when(
      () => repository.watchAll(),
    ).thenAnswer((_) => Stream.error(const StorageFailure()));

    await expectLater(
      watchTrends()(TrendRange.month),
      emitsError(isA<StorageFailure>()),
    );
  });
}
