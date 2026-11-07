import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_photo.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/usecases/get_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/save_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/update_check_in.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_cubit.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_state.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockSaveCheckIn extends Mock implements SaveCheckIn {}

class _MockUpdateCheckIn extends Mock implements UpdateCheckIn {}

class _MockGetCheckIn extends Mock implements GetCheckIn {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

void main() {
  late _MockSaveCheckIn saveCheckIn;
  late _MockUpdateCheckIn updateCheckIn;
  late _MockGetCheckIn getCheckIn;
  late _MockPhotoPicker photoPicker;

  final day = CalendarDay(2026, 11, 6);
  final stored = CheckIn(
    id: '1',
    date: day,
    photoPaths: const ['photos/1.jpg', 'photos/2.jpg'],
    workoutType: WorkoutType.cardio,
    note: 'Intervals',
    createdAt: DateTime(2026, 11, 6, 7, 42),
  );
  const picked = PickedPhoto('/tmp/camera.jpg');
  const ready = CheckInState(
    photos: [picked],
    workoutType: WorkoutType.cardio,
    note: 'Intervals',
  );
  final loaded = CheckInState(
    isEditing: true,
    original: stored,
    photos: const [StoredPhoto('photos/1.jpg'), StoredPhoto('photos/2.jpg')],
    workoutType: WorkoutType.cardio,
    note: 'Intervals',
  );

  setUpAll(() {
    registerFallbackValue(WorkoutType.other);
    registerFallbackValue(OtherActivity.sport);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<CheckInPhoto>[]);
  });

  setUp(() {
    saveCheckIn = _MockSaveCheckIn();
    updateCheckIn = _MockUpdateCheckIn();
    getCheckIn = _MockGetCheckIn();
    photoPicker = _MockPhotoPicker();
  });

  void stubSave(Future<CheckIn> Function() answer) {
    when(
      () => saveCheckIn(
        sourcePhotoPaths: any(named: 'sourcePhotoPaths'),
        workoutType: any(named: 'workoutType'),
        activity: any(named: 'activity'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) => answer());
  }

  void stubUpdate(Future<CheckIn> Function() answer) {
    when(
      () => updateCheckIn(
        id: any(named: 'id'),
        photos: any(named: 'photos'),
        workoutType: any(named: 'workoutType'),
        activity: any(named: 'activity'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) => answer());
  }

  CheckInCubit buildCubit({CalendarDay? editingDay}) => CheckInCubit(
    saveCheckIn: saveCheckIn,
    updateCheckIn: updateCheckIn,
    getCheckIn: getCheckIn,
    photoPicker: photoPicker,
    editingDay: editingDay,
  );

  group('CheckInState', () {
    test('needs a photo and a workout type before it can save', () {
      expect(const CheckInState().canSave, isFalse);
      expect(const CheckInState(photos: [picked]).canSave, isFalse);
      expect(
        const CheckInState(workoutType: WorkoutType.other).canSave,
        isFalse,
      );
      expect(ready.canSave, isTrue);
    });

    test('cannot save twice at once', () {
      expect(ready.copyWith(status: CheckInStatus.saving).canSave, isFalse);
    });

    test('cannot save while a photo is still being prepared', () {
      expect(ready.copyWith(isPickingPhoto: true).canSave, isFalse);
    });

    test('holds a limited number of photos', () {
      final full = CheckInState(
        photos: [
          for (var i = 0; i < CheckIn.maxPhotos; i++) PickedPhoto('/tmp/$i'),
        ],
      );

      expect(const CheckInState(photos: [picked]).canAddPhoto, isTrue);
      expect(full.canAddPhoto, isFalse);
    });

    test('for a new check-in, a photo or note counts as unsaved work, but a '
        'workout type alone does not', () {
      expect(const CheckInState().hasUnsavedChanges, isFalse);
      expect(
        const CheckInState(workoutType: WorkoutType.other).hasUnsavedChanges,
        isFalse,
      );
      expect(const CheckInState(note: '   ').hasUnsavedChanges, isFalse);
      expect(const CheckInState(note: 'Legs').hasUnsavedChanges, isTrue);
      expect(const CheckInState(photos: [picked]).hasUnsavedChanges, isTrue);
    });

    test("for a new check-in, an Other workout's activity alone is not "
        'unsaved work', () {
      expect(
        const CheckInState(
          workoutType: WorkoutType.other,
          activity: OtherActivity.walk,
        ).hasUnsavedChanges,
        isFalse,
      );
    });

    test('an edit is unsaved only once something differs', () {
      expect(loaded.hasUnsavedChanges, isFalse);
      expect(loaded.canSave, isFalse);
      expect(loaded.copyWith(note: ' Intervals ').hasUnsavedChanges, isFalse);

      for (final changed in [
        loaded.copyWith(note: 'Hills'),
        loaded.copyWith(workoutType: WorkoutType.other),
        loaded.copyWith(
          workoutType: WorkoutType.other,
          activity: () => OtherActivity.walk,
        ),
        loaded.copyWith(photos: const [StoredPhoto('photos/1.jpg')]),
        loaded.copyWith(photos: [...loaded.photos, picked]),
      ]) {
        expect(changed.hasUnsavedChanges, isTrue);
        expect(changed.canSave, isTrue);
      }
    });
  });

  group('load', () {
    test('a new check-in starts ready, with nothing to load', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state, const CheckInState());
      verifyZeroInteractions(getCheckIn);
    });

    blocTest<CheckInCubit, CheckInState>(
      'an edit starts loading, then fills in from the stored check-in',
      setUp: () => when(() => getCheckIn(day)).thenAnswer((_) async => stored),
      build: () => buildCubit(editingDay: day),
      act: (cubit) {
        expect(cubit.state.status, CheckInStatus.loading);
        expect(cubit.state.isEditing, isTrue);
        return cubit.load();
      },
      expect: () => [loaded],
    );

    blocTest<CheckInCubit, CheckInState>(
      "an edit fills in an Other workout's activity",
      setUp: () => when(() => getCheckIn(day)).thenAnswer(
        (_) async => CheckIn(
          id: '1',
          date: day,
          photoPaths: const ['photos/1.jpg'],
          workoutType: WorkoutType.other,
          activity: OtherActivity.groupClass,
          createdAt: DateTime(2026, 11, 6, 7, 42),
        ),
      ),
      build: () => buildCubit(editingDay: day),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.workoutType, WorkoutType.other);
        expect(cubit.state.activity, OtherActivity.groupClass);
        expect(cubit.state.hasUnsavedChanges, isFalse);
      },
    );

    blocTest<CheckInCubit, CheckInState>(
      'an edit fails if the check-in is gone',
      setUp: () => when(() => getCheckIn(day)).thenAnswer((_) async => null),
      build: () => buildCubit(editingDay: day),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CheckInState(isEditing: true, status: CheckInStatus.loadFailed),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'an edit fails if the check-in cannot be read',
      setUp: () => when(
        () => getCheckIn(day),
      ).thenAnswer((_) async => throw const StorageFailure()),
      build: () => buildCubit(editingDay: day),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CheckInState(isEditing: true, status: CheckInStatus.loadFailed),
      ],
    );
  });

  group('photos', () {
    blocTest<CheckInCubit, CheckInState>(
      'adds the photo the camera returns',
      setUp: () => when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => '/tmp/camera.jpg'),
      build: buildCubit,
      act: (cubit) => cubit.takePhoto(),
      expect: () => [
        const CheckInState(isPickingPhoto: true),
        const CheckInState(photos: [picked]),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'adds to the photos already there, in order',
      setUp: () => when(
        () => photoPicker.pickFromLibrary(),
      ).thenAnswer((_) async => '/tmp/second.jpg'),
      build: buildCubit,
      seed: () => const CheckInState(photos: [picked]),
      act: (cubit) => cubit.pickFromLibrary(),
      skip: 1,
      expect: () => [
        const CheckInState(photos: [picked, PickedPhoto('/tmp/second.jpg')]),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'keeps the photos as they were when the user cancels',
      setUp: () =>
          when(() => photoPicker.takePhoto()).thenAnswer((_) async => null),
      build: buildCubit,
      seed: () => ready,
      act: (cubit) => cubit.takePhoto(),
      expect: () => [ready.copyWith(isPickingPhoto: true), ready],
    );

    blocTest<CheckInCubit, CheckInState>(
      'with camera access off, reports it and leaves the form usable',
      setUp: () => when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => throw const PhotoUnavailable('denied')),
      build: buildCubit,
      act: (cubit) => cubit.takePhoto(),
      expect: () => [
        const CheckInState(isPickingPhoto: true),
        const CheckInState(photoProblem: PhotoProblem.cameraUnavailable),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'picking from the library after that clears the problem',
      setUp: () => when(
        () => photoPicker.pickFromLibrary(),
      ).thenAnswer((_) async => '/tmp/camera.jpg'),
      build: buildCubit,
      seed: () =>
          const CheckInState(photoProblem: PhotoProblem.cameraUnavailable),
      act: (cubit) => cubit.pickFromLibrary(),
      skip: 1,
      expect: () => [
        const CheckInState(photos: [picked]),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'reports a library photo that cannot be read',
      setUp: () => when(
        () => photoPicker.pickFromLibrary(),
      ).thenAnswer((_) async => throw const PhotoUnavailable('invalid_image')),
      build: buildCubit,
      act: (cubit) => cubit.pickFromLibrary(),
      skip: 1,
      expect: () => [
        const CheckInState(photoProblem: PhotoProblem.libraryUnavailable),
      ],
    );

    test('ignores a second request while a picker is open', () async {
      final picking = Completer<String?>();
      when(() => photoPicker.takePhoto()).thenAnswer((_) => picking.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final first = cubit.takePhoto();
      await cubit.takePhoto();
      await cubit.pickFromLibrary();
      picking.complete('/tmp/camera.jpg');
      await first;

      verify(() => photoPicker.takePhoto()).called(1);
      verifyNever(() => photoPicker.pickFromLibrary());
      expect(cubit.state.photos, [picked]);
    });

    blocTest<CheckInCubit, CheckInState>(
      'does not open a picker once the check-in is full',
      build: buildCubit,
      seed: () => CheckInState(
        photos: [
          for (var i = 0; i < CheckIn.maxPhotos; i++) PickedPhoto('/tmp/$i'),
        ],
      ),
      act: (cubit) => cubit.takePhoto(),
      expect: () => const <CheckInState>[],
      verify: (_) => verifyNever(() => photoPicker.takePhoto()),
    );

    test('ignores a photo that arrives after the screen closes', () async {
      when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => '/tmp/camera.jpg');
      final cubit = buildCubit();

      final taking = cubit.takePhoto();
      await cubit.close();

      await expectLater(taking, completes);
    });

    blocTest<CheckInCubit, CheckInState>(
      'removes a photo, keeping the others in order',
      build: buildCubit,
      seed: () => const CheckInState(
        photos: [
          PickedPhoto('/tmp/a.jpg'),
          StoredPhoto('photos/b.jpg'),
          PickedPhoto('/tmp/c.jpg'),
        ],
      ),
      act: (cubit) => cubit.removePhoto(const StoredPhoto('photos/b.jpg')),
      expect: () => [
        const CheckInState(
          photos: [PickedPhoto('/tmp/a.jpg'), PickedPhoto('/tmp/c.jpg')],
        ),
      ],
    );

    test('opening Settings goes through the picker', () async {
      when(() => photoPicker.openSettings()).thenAnswer((_) async {});
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.openSettings();

      verify(() => photoPicker.openSettings()).called(1);
    });
  });

  group('details', () {
    blocTest<CheckInCubit, CheckInState>(
      'keeps the selected workout type',
      build: buildCubit,
      act: (cubit) => cubit.selectWorkoutType(WorkoutType.mobility),
      expect: () => [const CheckInState(workoutType: WorkoutType.mobility)],
    );

    blocTest<CheckInCubit, CheckInState>(
      'chooses an activity for an Other workout, and tapping it again '
      'clears it',
      build: buildCubit,
      seed: () => const CheckInState(workoutType: WorkoutType.other),
      act: (cubit) => cubit
        ..toggleActivity(OtherActivity.sport)
        ..toggleActivity(OtherActivity.walk)
        ..toggleActivity(OtherActivity.walk),
      expect: () => [
        const CheckInState(
          workoutType: WorkoutType.other,
          activity: OtherActivity.sport,
        ),
        const CheckInState(
          workoutType: WorkoutType.other,
          activity: OtherActivity.walk,
        ),
        const CheckInState(workoutType: WorkoutType.other),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'ignores an activity for any other workout type',
      build: buildCubit,
      seed: () => const CheckInState(workoutType: WorkoutType.cardio),
      act: (cubit) => cubit.toggleActivity(OtherActivity.sport),
      expect: () => <CheckInState>[],
    );

    blocTest<CheckInCubit, CheckInState>(
      'switching away from Other drops its activity, and switching back '
      'does not bring it back',
      build: buildCubit,
      seed: () => const CheckInState(
        workoutType: WorkoutType.other,
        activity: OtherActivity.sport,
      ),
      act: (cubit) => cubit
        ..selectWorkoutType(WorkoutType.cardio)
        ..selectWorkoutType(WorkoutType.other),
      expect: () => [
        const CheckInState(workoutType: WorkoutType.cardio),
        const CheckInState(workoutType: WorkoutType.other),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'choosing Other again keeps its activity',
      build: buildCubit,
      seed: () => const CheckInState(
        workoutType: WorkoutType.other,
        activity: OtherActivity.sport,
      ),
      act: (cubit) => cubit.selectWorkoutType(WorkoutType.other),
      expect: () => <CheckInState>[],
    );

    blocTest<CheckInCubit, CheckInState>(
      'keeps the note as it is typed',
      build: buildCubit,
      act: (cubit) => cubit.noteChanged('Leg day'),
      expect: () => [const CheckInState(note: 'Leg day')],
    );
  });

  group('save', () {
    blocTest<CheckInCubit, CheckInState>(
      'saves a new check-in with every photo, then reports success',
      setUp: () => stubSave(() async => stored),
      build: buildCubit,
      seed: () => const CheckInState(
        photos: [picked, PickedPhoto('/tmp/second.jpg')],
        workoutType: WorkoutType.cardio,
        note: 'Intervals',
      ),
      act: (cubit) => cubit.save(),
      skip: 1,
      expect: () => [
        const CheckInState(
          photos: [picked, PickedPhoto('/tmp/second.jpg')],
          workoutType: WorkoutType.cardio,
          note: 'Intervals',
          status: CheckInStatus.saved,
        ),
      ],
      verify: (_) {
        verify(
          () => saveCheckIn(
            sourcePhotoPaths: ['/tmp/camera.jpg', '/tmp/second.jpg'],
            workoutType: WorkoutType.cardio,
            note: 'Intervals',
          ),
        ).called(1);
        verifyZeroInteractions(updateCheckIn);
      },
    );

    blocTest<CheckInCubit, CheckInState>(
      'updates an edited check-in, and does not make a new one',
      setUp: () => stubUpdate(() async => stored),
      build: () => buildCubit(editingDay: day),
      seed: () => loaded.copyWith(
        photos: const [StoredPhoto('photos/2.jpg'), picked],
        workoutType: WorkoutType.mobility,
        note: 'Hips',
      ),
      act: (cubit) => cubit.save(),
      verify: (cubit) {
        expect(cubit.state.status, CheckInStatus.saved);
        verify(
          () => updateCheckIn(
            id: '1',
            photos: const [StoredPhoto('photos/2.jpg'), picked],
            workoutType: WorkoutType.mobility,
            activity: null,
            note: 'Hips',
          ),
        ).called(1);
        verifyZeroInteractions(saveCheckIn);
      },
    );

    blocTest<CheckInCubit, CheckInState>(
      "saves an Other workout's activity",
      setUp: () => stubSave(() async => stored),
      build: buildCubit,
      seed: () => const CheckInState(
        photos: [picked],
        workoutType: WorkoutType.other,
        activity: OtherActivity.walk,
      ),
      act: (cubit) => cubit.save(),
      verify: (_) => verify(
        () => saveCheckIn(
          sourcePhotoPaths: ['/tmp/camera.jpg'],
          workoutType: WorkoutType.other,
          activity: OtherActivity.walk,
          note: '',
        ),
      ).called(1),
    );

    blocTest<CheckInCubit, CheckInState>(
      "updates an edited check-in's activity",
      setUp: () => stubUpdate(() async => stored),
      build: () => buildCubit(editingDay: day),
      seed: () => loaded.copyWith(
        workoutType: WorkoutType.other,
        activity: () => OtherActivity.groupClass,
      ),
      act: (cubit) => cubit.save(),
      verify: (_) => verify(
        () => updateCheckIn(
          id: '1',
          photos: loaded.photos,
          workoutType: WorkoutType.other,
          activity: OtherActivity.groupClass,
          note: 'Intervals',
        ),
      ).called(1),
    );

    blocTest<CheckInCubit, CheckInState>(
      'on failure keeps every field, so the user can retry',
      setUp: () => stubSave(() async => throw const StorageFailure()),
      build: buildCubit,
      seed: () => ready,
      act: (cubit) => cubit.save(),
      expect: () => [
        ready.copyWith(status: CheckInStatus.saving),
        ready.copyWith(status: CheckInStatus.failure),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'can try again after a failure',
      setUp: () => stubSave(() async => stored),
      build: buildCubit,
      seed: () => ready.copyWith(status: CheckInStatus.failure),
      act: (cubit) => cubit.save(),
      skip: 1,
      expect: () => [ready.copyWith(status: CheckInStatus.saved)],
    );

    blocTest<CheckInCubit, CheckInState>(
      'does nothing until the form can be saved',
      build: buildCubit,
      seed: () => const CheckInState(workoutType: WorkoutType.cardio),
      act: (cubit) => cubit.save(),
      expect: () => const <CheckInState>[],
      verify: (_) => verifyZeroInteractions(saveCheckIn),
    );

    blocTest<CheckInCubit, CheckInState>(
      'does not save twice when already saving',
      build: buildCubit,
      seed: () => ready.copyWith(status: CheckInStatus.saving),
      act: (cubit) => cubit.save(),
      expect: () => const <CheckInState>[],
      verify: (_) => verifyZeroInteractions(saveCheckIn),
    );
  });
}
