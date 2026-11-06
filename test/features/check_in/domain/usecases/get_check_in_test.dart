import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/check_in/domain/usecases/get_check_in.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

void main() {
  late _MockCheckInRepository repository;
  late GetCheckIn getCheckIn;

  final oct5 = CalendarDay(2026, 10, 5);

  setUp(() {
    repository = _MockCheckInRepository();
    getCheckIn = GetCheckIn(repository: repository);
  });

  test('returns the check-in for the day', () async {
    final checkIn = CheckIn(
      id: '1',
      date: oct5,
      photoPaths: const ['photos/1.jpg'],
      workoutType: WorkoutType.cardio,
      createdAt: DateTime(2026, 10, 5, 7, 42),
    );
    when(() => repository.findByDate(oct5)).thenAnswer((_) async => checkIn);

    expect(await getCheckIn(oct5), checkIn);
  });

  test('returns null when the day has no check-in', () async {
    when(() => repository.findByDate(oct5)).thenAnswer((_) async => null);

    expect(await getCheckIn(oct5), isNull);
  });

  test('passes a storage failure on to the caller', () async {
    when(
      () => repository.findByDate(oct5),
    ).thenAnswer((_) async => throw const StorageFailure());

    await expectLater(getCheckIn(oct5), throwsA(isA<StorageFailure>()));
  });
}
