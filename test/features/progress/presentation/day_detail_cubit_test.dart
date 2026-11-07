import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_photo.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/usecases/delete_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/update_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/watch_check_in.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:gym_grid/features/progress/presentation/day_detail_cubit.dart';
import 'package:gym_grid/features/progress/presentation/day_detail_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchCheckIn extends Mock implements WatchCheckIn {}

class _MockUpdateCheckIn extends Mock implements UpdateCheckIn {}

class _MockDeleteCheckIn extends Mock implements DeleteCheckIn {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

void main() {
  late _MockWatchCheckIn watchCheckIn;
  late _MockUpdateCheckIn updateCheckIn;
  late _MockDeleteCheckIn deleteCheckIn;
  late _MockPhotoPicker photoPicker;
  late StreamController<CheckIn?> checkIns;

  final day = CalendarDay(2026, 11, 6);
  final stored = CheckIn(
    id: '1',
    date: day,
    photoPaths: const ['photos/1.jpg'],
    workoutType: WorkoutType.cardio,
    note: 'Intervals',
    createdAt: DateTime(2026, 11, 6, 7, 42),
  );
  final loaded = DayDetailLoaded(stored);

  setUpAll(() {
    registerFallbackValue(WorkoutType.other);
    registerFallbackValue(OtherActivity.sport);
    registerFallbackValue(Rating.medium);
    registerFallbackValue(<CheckInPhoto>[]);
  });

  setUp(() {
    watchCheckIn = _MockWatchCheckIn();
    updateCheckIn = _MockUpdateCheckIn();
    deleteCheckIn = _MockDeleteCheckIn();
    photoPicker = _MockPhotoPicker();
    when(() => photoPicker.discard(any())).thenAnswer((_) async {});
    checkIns = StreamController<CheckIn?>.broadcast();
    addTearDown(checkIns.close);
    when(() => watchCheckIn(day)).thenAnswer((_) => checkIns.stream);
  });

  void stubUpdate(Future<CheckIn> Function() answer) {
    when(
      () => updateCheckIn(
        id: any(named: 'id'),
        photos: any(named: 'photos'),
        workoutType: any(named: 'workoutType'),
        activity: any(named: 'activity'),
        effort: any(named: 'effort'),
        energy: any(named: 'energy'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) => answer());
  }

  DayDetailCubit buildCubit() => DayDetailCubit(
    day: day,
    watchCheckIn: watchCheckIn,
    updateCheckIn: updateCheckIn,
    deleteCheckIn: deleteCheckIn,
    photoPicker: photoPicker,
  );

  group('watching', () {
    test('starts out loading', () {
      expect(buildCubit().state, const DayDetailLoading());
    });

    blocTest<DayDetailCubit, DayDetailState>(
      'shows the check-in, and each change to it',
      build: buildCubit,
      act: (cubit) async {
        cubit.watch();
        checkIns.add(stored);
        await pumpEventQueue();
        checkIns.add(
          CheckIn(
            id: '1',
            date: day,
            photoPaths: const ['photos/1.jpg', 'photos/2.jpg'],
            workoutType: WorkoutType.cardio,
            createdAt: stored.createdAt,
          ),
        );
        await pumpEventQueue();
      },
      verify: (cubit) {
        final state = cubit.state as DayDetailLoaded;
        expect(state.checkIn.photoPaths, hasLength(2));
      },
    );

    blocTest<DayDetailCubit, DayDetailState>(
      'reports a day with no check-in',
      build: buildCubit,
      act: (cubit) async {
        cubit.watch();
        checkIns.add(null);
        await pumpEventQueue();
      },
      expect: () => [const DayDetailNotFound()],
    );

    blocTest<DayDetailCubit, DayDetailState>(
      'reports a failure, and trying again reloads',
      build: buildCubit,
      act: (cubit) async {
        cubit.watch();
        checkIns.addError(const StorageFailure());
        await pumpEventQueue();
        cubit.watch();
        checkIns.add(stored);
        await pumpEventQueue();
      },
      expect: () => [
        const DayDetailFailure(StorageFailure()),
        const DayDetailLoading(),
        loaded,
      ],
    );

    test('cancels the subscription when closed', () async {
      final cubit = buildCubit()..watch();

      await cubit.close();

      expect(checkIns.hasListener, isFalse);
    });
  });

  group('adding a photo', () {
    blocTest<DayDetailCubit, DayDetailState>(
      'adds the picked photo after the existing ones',
      setUp: () {
        when(
          () => photoPicker.takePhoto(),
        ).thenAnswer((_) async => '/tmp/new.jpg');
        stubUpdate(() async => stored);
      },
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.takePhoto(),
      expect: () => [
        loaded.copyWith(activity: DayDetailActivity.addingPhoto),
        loaded,
      ],
      verify: (_) => verify(
        () => updateCheckIn(
          id: '1',
          photos: const [
            StoredPhoto('photos/1.jpg'),
            PickedPhoto('/tmp/new.jpg'),
          ],
          workoutType: WorkoutType.cardio,
          activity: null,
          effort: null,
          energy: null,
          note: 'Intervals',
        ),
      ).called(1),
    );

    blocTest<DayDetailCubit, DayDetailState>(
      'discards the picked file once it is stored',
      setUp: () {
        when(
          () => photoPicker.takePhoto(),
        ).thenAnswer((_) async => '/tmp/new.jpg');
        stubUpdate(() async => stored);
      },
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.takePhoto(),
      verify: (_) =>
          verify(() => photoPicker.discard('/tmp/new.jpg')).called(1),
    );

    blocTest<DayDetailCubit, DayDetailState>(
      'discards the picked file when it cannot be stored, too',
      setUp: () {
        when(
          () => photoPicker.takePhoto(),
        ).thenAnswer((_) async => '/tmp/new.jpg');
        stubUpdate(() async => throw const StorageFailure());
      },
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.takePhoto(),
      verify: (cubit) {
        verify(() => photoPicker.discard('/tmp/new.jpg')).called(1);
        expect(
          (cubit.state as DayDetailLoaded).error,
          DayDetailError.photoNotSaved,
        );
      },
    );

    test('discards a photo that arrives after the screen closes', () async {
      final photo = Completer<String?>();
      when(() => photoPicker.takePhoto()).thenAnswer((_) => photo.future);
      final cubit = buildCubit()..emit(loaded);

      final adding = cubit.takePhoto();
      await cubit.close();
      photo.complete('/tmp/late.jpg');
      await adding;

      verify(() => photoPicker.discard('/tmp/late.jpg')).called(1);
      verifyNever(
        () => updateCheckIn(
          id: any(named: 'id'),
          photos: any(named: 'photos'),
          workoutType: any(named: 'workoutType'),
          activity: any(named: 'activity'),
          effort: any(named: 'effort'),
          energy: any(named: 'energy'),
          note: any(named: 'note'),
        ),
      );
    });

    blocTest<DayDetailCubit, DayDetailState>(
      'keeps the effort and energy',
      setUp: () {
        when(
          () => photoPicker.takePhoto(),
        ).thenAnswer((_) async => '/tmp/new.jpg');
        stubUpdate(() async => stored);
      },
      build: buildCubit,
      seed: () => DayDetailLoaded(
        CheckIn(
          id: '1',
          date: day,
          photoPaths: const ['photos/1.jpg'],
          workoutType: WorkoutType.strength,
          effort: Rating.max,
          energy: Rating.low,
          createdAt: DateTime(2026, 11, 6, 7, 42),
        ),
      ),
      act: (cubit) => cubit.takePhoto(),
      verify: (_) => verify(
        () => updateCheckIn(
          id: '1',
          photos: const [
            StoredPhoto('photos/1.jpg'),
            PickedPhoto('/tmp/new.jpg'),
          ],
          workoutType: WorkoutType.strength,
          activity: null,
          effort: Rating.max,
          energy: Rating.low,
          note: null,
        ),
      ).called(1),
    );

    blocTest<DayDetailCubit, DayDetailState>(
      "keeps an Other workout's activity",
      setUp: () {
        when(
          () => photoPicker.takePhoto(),
        ).thenAnswer((_) async => '/tmp/new.jpg');
        stubUpdate(() async => stored);
      },
      build: buildCubit,
      seed: () => DayDetailLoaded(
        CheckIn(
          id: '1',
          date: day,
          photoPaths: const ['photos/1.jpg'],
          workoutType: WorkoutType.other,
          activity: OtherActivity.sport,
          createdAt: DateTime(2026, 11, 6, 7, 42),
        ),
      ),
      act: (cubit) => cubit.takePhoto(),
      verify: (_) => verify(
        () => updateCheckIn(
          id: '1',
          photos: const [
            StoredPhoto('photos/1.jpg'),
            PickedPhoto('/tmp/new.jpg'),
          ],
          workoutType: WorkoutType.other,
          activity: OtherActivity.sport,
          effort: null,
          energy: null,
          note: null,
        ),
      ).called(1),
    );

    blocTest<DayDetailCubit, DayDetailState>(
      'can come from the library',
      setUp: () {
        when(
          () => photoPicker.pickFromLibrary(),
        ).thenAnswer((_) async => '/tmp/new.jpg');
        stubUpdate(() async => stored);
      },
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.pickFromLibrary(),
      verify: (_) => verify(() => photoPicker.pickFromLibrary()).called(1),
    );

    blocTest<DayDetailCubit, DayDetailState>(
      'changes nothing when the user cancels',
      setUp: () =>
          when(() => photoPicker.takePhoto()).thenAnswer((_) async => null),
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.takePhoto(),
      expect: () => [
        loaded.copyWith(activity: DayDetailActivity.addingPhoto),
        loaded,
      ],
      verify: (_) => verifyZeroInteractions(updateCheckIn),
    );

    blocTest<DayDetailCubit, DayDetailState>(
      'with camera access off, explains that',
      setUp: () => when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => throw const PhotoUnavailable('denied')),
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.takePhoto(),
      skip: 1,
      expect: () => [
        loaded.copyWith(photoProblem: () => PhotoProblem.cameraUnavailable),
      ],
    );

    blocTest<DayDetailCubit, DayDetailState>(
      'reports a photo that cannot be stored',
      setUp: () {
        when(
          () => photoPicker.takePhoto(),
        ).thenAnswer((_) async => '/tmp/new.jpg');
        stubUpdate(() async => throw const StorageFailure());
      },
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.takePhoto(),
      skip: 1,
      expect: () => [
        loaded.copyWith(error: () => DayDetailError.photoNotSaved),
      ],
    );

    blocTest<DayDetailCubit, DayDetailState>(
      'clears an earlier message when trying again',
      setUp: () =>
          when(() => photoPicker.takePhoto()).thenAnswer((_) async => null),
      build: buildCubit,
      seed: () => loaded.copyWith(error: () => DayDetailError.photoNotSaved),
      act: (cubit) => cubit.takePhoto(),
      skip: 1,
      expect: () => [loaded],
    );

    test('holds a limited number of photos', () {
      final full = DayDetailLoaded(
        CheckIn(
          id: '1',
          date: day,
          photoPaths: [
            for (var i = 0; i < CheckIn.maxPhotos; i++) 'photos/$i.jpg',
          ],
          workoutType: WorkoutType.other,
          createdAt: stored.createdAt,
        ),
      );

      expect(loaded.canAddPhoto, isTrue);
      expect(full.canAddPhoto, isFalse);
    });

    test('ignores a second request while one is running', () async {
      final picking = Completer<String?>();
      when(() => photoPicker.takePhoto()).thenAnswer((_) => picking.future);
      final cubit = buildCubit()..emit(loaded);
      addTearDown(cubit.close);

      final first = cubit.takePhoto();
      await cubit.takePhoto();
      await cubit.pickFromLibrary();
      picking.complete(null);
      await first;

      verify(() => photoPicker.takePhoto()).called(1);
      verifyNever(() => photoPicker.pickFromLibrary());
    });
  });

  group('delete', () {
    blocTest<DayDetailCubit, DayDetailState>(
      'deletes the check-in, then says so',
      setUp: () => when(() => deleteCheckIn('1')).thenAnswer((_) async {}),
      build: buildCubit,
      seed: () => loaded,
      act: (cubit) => cubit.delete(),
      expect: () => [
        loaded.copyWith(activity: DayDetailActivity.deleting),
        const DayDetailDeleted(),
      ],
    );

    test('does not flash "not found" while the deletion lands', () async {
      when(() => deleteCheckIn('1')).thenAnswer((_) async {
        // The stream reports the deletion before the delete call returns.
        checkIns.add(null);
      });
      final cubit = buildCubit()..watch();
      addTearDown(cubit.close);
      checkIns.add(stored);
      await pumpEventQueue();
      final states = <DayDetailState>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      await cubit.delete();
      await pumpEventQueue();

      expect(states, isNot(contains(const DayDetailNotFound())));
      expect(states.last, const DayDetailDeleted());
    });

    test('on failure keeps the check-in and goes on watching it', () async {
      when(
        () => deleteCheckIn('1'),
      ).thenAnswer((_) async => throw const StorageFailure());
      final cubit = buildCubit()..watch();
      addTearDown(cubit.close);
      checkIns.add(stored);
      await pumpEventQueue();

      await cubit.delete();
      await pumpEventQueue();

      expect(
        cubit.state,
        loaded.copyWith(error: () => DayDetailError.notDeleted),
      );
      expect(checkIns.hasListener, isTrue);
    });

    blocTest<DayDetailCubit, DayDetailState>(
      'does nothing while another action runs',
      build: buildCubit,
      seed: () => loaded.copyWith(activity: DayDetailActivity.addingPhoto),
      act: (cubit) => cubit.delete(),
      expect: () => const <DayDetailState>[],
      verify: (_) => verifyZeroInteractions(deleteCheckIn),
    );
  });
}
