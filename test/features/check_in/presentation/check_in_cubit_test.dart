import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/date/clock.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/usecases/get_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/save_check_in.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_cubit.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_state.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockSaveCheckIn extends Mock implements SaveCheckIn {}

class _MockGetCheckIn extends Mock implements GetCheckIn {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

void main() {
  late _MockSaveCheckIn saveCheckIn;
  late _MockGetCheckIn getCheckIn;
  late _MockPhotoPicker photoPicker;

  final today = CalendarDay(2026, 11, 6);
  final stored = CheckIn(
    id: '1',
    date: today,
    photoPath: 'photos/1.jpg',
    workoutType: WorkoutType.cardio,
    createdAt: DateTime(2026, 11, 6, 7, 42),
  );
  const ready = CheckInState(
    photoPath: '/tmp/camera.jpg',
    workoutType: WorkoutType.cardio,
    note: 'Intervals',
  );

  setUpAll(() => registerFallbackValue(WorkoutType.other));

  setUp(() {
    saveCheckIn = _MockSaveCheckIn();
    getCheckIn = _MockGetCheckIn();
    photoPicker = _MockPhotoPicker();
  });

  void stubSave(Future<CheckIn> Function() answer) {
    when(
      () => saveCheckIn(
        sourcePhotoPath: any(named: 'sourcePhotoPath'),
        workoutType: any(named: 'workoutType'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) => answer());
  }

  CheckInCubit buildCubit() => CheckInCubit(
    saveCheckIn: saveCheckIn,
    getCheckIn: getCheckIn,
    photoPicker: photoPicker,
    clock: Clock(() => DateTime(2026, 11, 6, 20)),
  );

  group('CheckInState', () {
    test('needs a photo and a workout type before it can save', () {
      expect(const CheckInState().canSave, isFalse);
      expect(const CheckInState(photoPath: '/a.jpg').canSave, isFalse);
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

    test('a photo or a note is a draft, but a workout type alone is not', () {
      expect(const CheckInState().hasDraft, isFalse);
      expect(
        const CheckInState(workoutType: WorkoutType.other).hasDraft,
        isFalse,
      );
      expect(const CheckInState(note: '   ').hasDraft, isFalse);
      expect(const CheckInState(note: 'Legs').hasDraft, isTrue);
      expect(const CheckInState(photoPath: '/a.jpg').hasDraft, isTrue);
    });
  });

  group('load', () {
    blocTest<CheckInCubit, CheckInState>(
      "notes when today already has a check-in, looking up today's date",
      setUp: () =>
          when(() => getCheckIn(today)).thenAnswer((_) async => stored),
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [const CheckInState(isReplacingToday: true)],
    );

    blocTest<CheckInCubit, CheckInState>(
      'stays as it is when today is free',
      setUp: () => when(() => getCheckIn(today)).thenAnswer((_) async => null),
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => const <CheckInState>[CheckInState()],
    );

    blocTest<CheckInCubit, CheckInState>(
      'carries on if the lookup fails, leaving errors to the save',
      setUp: () => when(
        () => getCheckIn(today),
      ).thenAnswer((_) async => throw const StorageFailure()),
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => const <CheckInState>[],
    );
  });

  group('getting a photo', () {
    blocTest<CheckInCubit, CheckInState>(
      'keeps the photo the camera returns',
      setUp: () => when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => '/tmp/camera.jpg'),
      build: buildCubit,
      act: (cubit) => cubit.takePhoto(),
      expect: () => [
        const CheckInState(isPickingPhoto: true),
        const CheckInState(photoPath: '/tmp/camera.jpg'),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'keeps the earlier photo when the user cancels a retake',
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
      ).thenAnswer((_) async => '/tmp/library.jpg'),
      build: buildCubit,
      seed: () =>
          const CheckInState(photoProblem: PhotoProblem.cameraUnavailable),
      act: (cubit) => cubit.pickFromLibrary(),
      expect: () => [
        const CheckInState(
          photoProblem: PhotoProblem.cameraUnavailable,
          isPickingPhoto: true,
        ),
        const CheckInState(photoPath: '/tmp/library.jpg'),
      ],
    );

    blocTest<CheckInCubit, CheckInState>(
      'reports a library photo that cannot be read',
      setUp: () => when(
        () => photoPicker.pickFromLibrary(),
      ).thenAnswer((_) async => throw const PhotoUnavailable('invalid_image')),
      build: buildCubit,
      act: (cubit) => cubit.pickFromLibrary(),
      expect: () => [
        const CheckInState(isPickingPhoto: true),
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
      expect(cubit.state.photoPath, '/tmp/camera.jpg');
    });

    test('ignores a photo that arrives after the screen closes', () async {
      when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => '/tmp/camera.jpg');
      final cubit = buildCubit();

      final taking = cubit.takePhoto();
      await cubit.close();

      await expectLater(taking, completes);
    });

    test('opening Settings goes through the picker', () async {
      when(() => photoPicker.openSettings()).thenAnswer((_) async {});
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.openSettings();

      verify(() => photoPicker.openSettings()).called(1);
    });
  });

  group('editing', () {
    blocTest<CheckInCubit, CheckInState>(
      'keeps the selected workout type',
      build: buildCubit,
      act: (cubit) => cubit.selectWorkoutType(WorkoutType.mobility),
      expect: () => [const CheckInState(workoutType: WorkoutType.mobility)],
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
      'saves the form, then reports success',
      setUp: () => stubSave(() async => stored),
      build: buildCubit,
      seed: () => ready,
      act: (cubit) => cubit.save(),
      expect: () => [
        ready.copyWith(status: CheckInStatus.saving),
        ready.copyWith(status: CheckInStatus.saved),
      ],
      verify: (_) => verify(
        () => saveCheckIn(
          sourcePhotoPath: '/tmp/camera.jpg',
          workoutType: WorkoutType.cardio,
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
      'does nothing without a photo',
      build: buildCubit,
      seed: () => const CheckInState(workoutType: WorkoutType.cardio),
      act: (cubit) => cubit.save(),
      expect: () => const <CheckInState>[],
      verify: (_) => verifyZeroInteractions(saveCheckIn),
    );

    blocTest<CheckInCubit, CheckInState>(
      'does nothing without a workout type',
      build: buildCubit,
      seed: () => const CheckInState(photoPath: '/tmp/camera.jpg'),
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
