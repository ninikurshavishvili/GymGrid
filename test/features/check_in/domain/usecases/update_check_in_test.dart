import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_edit.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_photo.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/check_in/domain/usecases/update_check_in.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

void main() {
  late _MockCheckInRepository repository;
  late UpdateCheckIn updateCheckIn;

  final stored = CheckIn(
    id: '1',
    date: CalendarDay(2026, 10, 5),
    photoPaths: const ['photos/1.jpg'],
    workoutType: WorkoutType.cardio,
    createdAt: DateTime(2026, 10, 5, 7, 42),
  );
  const photos = [StoredPhoto('photos/1.jpg'), PickedPhoto('/tmp/new.jpg')];

  setUpAll(
    () => registerFallbackValue(
      const CheckInEdit(id: '', photos: [], workoutType: WorkoutType.other),
    ),
  );

  setUp(() {
    repository = _MockCheckInRepository();
    updateCheckIn = UpdateCheckIn(repository: repository);
    when(() => repository.update(any())).thenAnswer((_) async => stored);
  });

  test('passes the edit on and returns the stored check-in', () async {
    final result = await updateCheckIn(
      id: '1',
      photos: photos,
      workoutType: WorkoutType.cardio,
      note: 'Intervals',
    );

    expect(result, stored);
    verify(
      () => repository.update(
        const CheckInEdit(
          id: '1',
          photos: photos,
          workoutType: WorkoutType.cardio,
          note: 'Intervals',
        ),
      ),
    ).called(1);
  });

  test('trims the note, and stores a blank one as no note', () async {
    await updateCheckIn(
      id: '1',
      photos: photos,
      workoutType: WorkoutType.cardio,
      note: '  Intervals\n',
    );
    await updateCheckIn(
      id: '1',
      photos: photos,
      workoutType: WorkoutType.cardio,
      note: '   ',
    );

    final edits = verify(
      () => repository.update(captureAny()),
    ).captured.cast<CheckInEdit>();
    expect(edits.first.note, 'Intervals');
    expect(edits.last.note, isNull);
  });

  test('passes a storage failure on to the caller', () async {
    when(
      () => repository.update(any()),
    ).thenAnswer((_) async => throw const StorageFailure());

    await expectLater(
      updateCheckIn(id: '1', photos: photos, workoutType: WorkoutType.cardio),
      throwsA(isA<StorageFailure>()),
    );
  });
}
