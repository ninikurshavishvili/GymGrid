import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/progress/domain/entities/progress.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_progress.dart';
import 'package:gym_grid/features/progress/presentation/home_cubit.dart';
import 'package:gym_grid/features/progress/presentation/home_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchProgress extends Mock implements WatchProgress {}

void main() {
  late _MockWatchProgress watchProgress;

  final today = CalendarDay(2026, 10, 5);
  final noCheckIns = Progress.from(const [], today: today);
  final oneCheckIn = Progress.from([
    CheckIn(
      id: '1',
      date: today,
      photoPath: 'photos/1.jpg',
      workoutType: WorkoutType.strength,
      createdAt: DateTime(2026, 10, 5, 7, 42),
    ),
  ], today: today);

  setUp(() => watchProgress = _MockWatchProgress());

  HomeCubit buildCubit() => HomeCubit(watchProgress: watchProgress);

  test('starts out loading', () {
    expect(buildCubit().state, const HomeLoading());
  });

  blocTest<HomeCubit, HomeState>(
    'shows the first progress',
    setUp: () =>
        when(() => watchProgress()).thenAnswer((_) => Stream.value(noCheckIns)),
    build: buildCubit,
    act: (cubit) => cubit.watch(),
    expect: () => [HomeLoaded(noCheckIns)],
  );

  blocTest<HomeCubit, HomeState>(
    'updates when a new check-in arrives',
    setUp: () => when(
      () => watchProgress(),
    ).thenAnswer((_) => Stream.fromIterable([noCheckIns, oneCheckIn])),
    build: buildCubit,
    act: (cubit) => cubit.watch(),
    expect: () => [HomeLoaded(noCheckIns), HomeLoaded(oneCheckIn)],
  );

  blocTest<HomeCubit, HomeState>(
    'shows a failure the stream reports',
    setUp: () => when(
      () => watchProgress(),
    ).thenAnswer((_) => Stream.error(const StorageFailure())),
    build: buildCubit,
    act: (cubit) => cubit.watch(),
    expect: () => [const HomeFailure(StorageFailure())],
  );

  group('after a failure', () {
    late int calls;

    setUp(() {
      calls = 0;
      when(() => watchProgress()).thenAnswer(
        (_) => ++calls == 1
            ? Stream.error(const StorageFailure())
            : Stream.value(oneCheckIn),
      );
    });

    blocTest<HomeCubit, HomeState>(
      'trying again subscribes again and loads',
      build: buildCubit,
      act: (cubit) async {
        cubit.watch();
        await pumpEventQueue();
        cubit.watch();
      },
      expect: () => [
        const HomeFailure(StorageFailure()),
        const HomeLoading(),
        HomeLoaded(oneCheckIn),
      ],
      verify: (_) => verify(() => watchProgress()).called(2),
    );
  });

  blocTest<HomeCubit, HomeState>(
    'recovers by itself if the same stream emits after a failure',
    setUp: () {
      final progress = StreamController<Progress>()
        ..addError(const StorageFailure())
        ..add(oneCheckIn);
      addTearDown(progress.close);
      when(() => watchProgress()).thenAnswer((_) => progress.stream);
    },
    build: buildCubit,
    act: (cubit) => cubit.watch(),
    expect: () => [const HomeFailure(StorageFailure()), HomeLoaded(oneCheckIn)],
  );

  test('cancels the subscription when watching again', () async {
    var cancelled = 0;
    final first = StreamController<Progress>(onCancel: () => cancelled++);
    addTearDown(first.close);
    when(() => watchProgress()).thenAnswer((_) => first.stream);
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.watch();
    when(() => watchProgress()).thenAnswer((_) => const Stream.empty());
    cubit.watch();

    expect(cancelled, 1);
  });

  test('cancels the subscription when closed', () async {
    var cancelled = false;
    final progress = StreamController<Progress>(
      onCancel: () => cancelled = true,
    );
    addTearDown(progress.close);
    when(() => watchProgress()).thenAnswer((_) => progress.stream);
    final cubit = buildCubit();

    cubit.watch();
    await cubit.close();

    expect(cancelled, isTrue);
  });

  test('leaves nothing listening if closed while an old subscription is still '
      'cancelling', () async {
    final cancelling = Completer<void>();
    final first = StreamController<Progress>(onCancel: () => cancelling.future);
    final second = StreamController<Progress>();
    addTearDown(first.close);
    addTearDown(second.close);
    final cubit = buildCubit();

    when(() => watchProgress()).thenAnswer((_) => first.stream);
    cubit.watch();
    when(() => watchProgress()).thenAnswer((_) => second.stream);
    cubit.watch();
    await cubit.close();
    cancelling.complete();
    await pumpEventQueue();

    expect(first.hasListener, isFalse);
    expect(second.hasListener, isFalse);
  });

  test('lets an error that is not a Failure surface as a bug', () async {
    when(
      () => watchProgress(),
    ).thenAnswer((_) => Stream.error(StateError('a bug')));
    final cubit = buildCubit();
    addTearDown(cubit.close);
    final uncaught = <Object>[];

    await runZonedGuarded(() async {
      cubit.watch();
      await pumpEventQueue();
    }, (error, _) => uncaught.add(error));

    expect(uncaught, [isA<StateError>()]);
    expect(cubit.state, const HomeLoading());
  });
}
