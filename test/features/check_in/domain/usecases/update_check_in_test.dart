import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_edit.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_photo.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';
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
      activity: null,
      effort: null,
      energy: null,
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
      activity: null,
      effort: null,
      energy: null,
      note: '  Intervals\n',
    );
    await updateCheckIn(
      id: '1',
      photos: photos,
      workoutType: WorkoutType.cardio,
      activity: null,
      effort: null,
      energy: null,
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
      updateCheckIn(
        id: '1',
        photos: photos,
        workoutType: WorkoutType.cardio,
        activity: null,
        effort: null,
        energy: null,
      ),
      throwsA(isA<StorageFailure>()),
    );
  });

  CheckInEdit sentEdit() =>
      verify(() => repository.update(captureAny())).captured.single
          as CheckInEdit;

  test('passes effort and energy on, for any workout type', () async {
    await updateCheckIn(
      id: '1',
      photos: photos,
      workoutType: WorkoutType.mobility,
      activity: null,
      effort: Rating.medium,
      energy: Rating.max,
    );

    final edit = sentEdit();
    expect(edit.effort, Rating.medium);
    expect(edit.energy, Rating.max);
  });

  test('keeps the activity of an Other workout', () async {
    await updateCheckIn(
      id: '1',
      photos: photos,
      workoutType: WorkoutType.other,
      activity: OtherActivity.groupClass,
      effort: null,
      energy: null,
    );

    expect(sentEdit().activity, OtherActivity.groupClass);
  });

  test('drops the activity of any other workout type', () async {
    await updateCheckIn(
      id: '1',
      photos: photos,
      workoutType: WorkoutType.mobility,
      activity: OtherActivity.groupClass,
      effort: null,
      energy: null,
    );

    expect(sentEdit().activity, isNull);
  });
}
