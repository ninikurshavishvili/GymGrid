import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/date/clock.dart';
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
      photoPaths: const ['photos/1.jpg'],
      workoutType: WorkoutType.strength,
      createdAt: DateTime(2026, 10, 5, 7, 42),
    ),
  ], today: today);

  setUp(() => watchProgress = _MockWatchProgress());

  HomeCubit buildCubit({Clock? clock}) => HomeCubit(
    watchProgress: watchProgress,
    clock: clock ?? Clock(() => DateTime(2026, 10, 5, 12)),
  );

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

  group('as the date changes', () {
    /// Runs [body] with a clock that moves with fake time, starting at
    /// [start], and a Cubit showing [progress].
    void withCubit(
      DateTime start,
      Progress progress,
      void Function(FakeAsync async, HomeCubit cubit, void Function(Duration))
      body,
    ) {
      fakeAsync((async) {
        var skipped = Duration.zero;
        when(() => watchProgress()).thenAnswer((_) => Stream.value(progress));
        final cubit = buildCubit(
          clock: Clock(() => start.add(async.elapsed).add(skipped)),
        )..watch();
        async.flushMicrotasks();

        body(async, cubit, (time) => skipped += time);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    }

    final lateEvening = DateTime(2026, 10, 5, 23, 59);

    Progress progressOf(HomeCubit cubit) =>
        (cubit.state as HomeLoaded).progress;

    test('moves to the new day at midnight while the app is open', () {
      withCubit(lateEvening, oneCheckIn, (async, cubit, _) {
        expect(progressOf(cubit).todaysCheckIn, isNotNull);

        async.elapse(const Duration(minutes: 1));

        final progress = progressOf(cubit);
        expect(progress.today, today.addDays(1));
        expect(progress.todaysCheckIn, isNull);
        expect(progress.streaks.isAtRisk, isTrue);
      });
    });

    test('does nothing before midnight', () {
      withCubit(lateEvening, oneCheckIn, (async, cubit, _) {
        async.elapse(const Duration(seconds: 59));

        expect(progressOf(cubit).today, today);
      });
    });

    test('keeps moving, midnight after midnight', () {
      withCubit(lateEvening, oneCheckIn, (async, cubit, _) {
        async.elapse(const Duration(minutes: 1));
        async.elapse(const Duration(hours: 24));

        final progress = progressOf(cubit);
        expect(progress.today, today.addDays(2));
        expect(progress.streaks.current, 0);
      });
    });

    test('catches up on resuming after the date changed', () {
      withCubit(DateTime(2026, 10, 5, 12), oneCheckIn, (async, cubit, skip) {
        // The timer sleeps in the background, so time passes without it.
        skip(const Duration(days: 2));

        cubit.appResumed();

        expect(progressOf(cubit).today, today.addDays(2));
      });
    });

    test('stays quiet on resuming the same day', () {
      withCubit(DateTime(2026, 10, 5, 12), oneCheckIn, (async, cubit, skip) {
        final before = cubit.state;
        final states = <HomeState>[];
        final subscription = cubit.stream.listen(states.add);

        cubit.appResumed();
        async.flushMicrotasks();

        expect(states, isEmpty);
        expect(cubit.state, same(before));
        unawaited(subscription.cancel());
      });
    });

    test('follows the clock backwards too, as after a time zone change', () {
      withCubit(DateTime(2026, 10, 5, 12), oneCheckIn, (async, cubit, skip) {
        skip(const Duration(days: -1));

        cubit.appResumed();

        expect(progressOf(cubit).today, today.addDays(-1));
        expect(progressOf(cubit).todaysCheckIn, isNull);
      });
    });

    test('aims for the new midnight after the clock changes', () {
      withCubit(DateTime(2026, 10, 5, 12), oneCheckIn, (async, cubit, skip) {
        // Moved to 23:00 on the same day, so midnight is now an hour off,
        // not the twelve the first timer was set for.
        skip(const Duration(hours: 11));
        cubit.appResumed();

        async.elapse(const Duration(hours: 1));

        expect(progressOf(cubit).today, today.addDays(1));
      });
    });

    test('crossing into a new year restarts the count, not the streak', () {
      final dec31 = CalendarDay(2026, 12, 31);
      final progress = Progress.from([
        CheckIn(
          id: '1',
          date: dec31,
          photoPaths: const ['photos/1.jpg'],
          workoutType: WorkoutType.strength,
          createdAt: DateTime(2026, 12, 31, 7),
        ),
      ], today: dec31);

      withCubit(DateTime(2026, 12, 31, 23, 59), progress, (async, cubit, _) {
        expect(progressOf(cubit).checkInCountThisYear, 1);

        async.elapse(const Duration(minutes: 1));

        final next = progressOf(cubit);
        expect(next.today, CalendarDay(2027, 1, 1));
        expect(next.checkInCountThisYear, 0);
        expect(next.streaks.current, 1);
        expect(next.streaks.isAtRisk, isTrue);
      });
    });

    test('has nothing to update while loading or after a failure', () {
      fakeAsync((async) {
        when(
          () => watchProgress(),
        ).thenAnswer((_) => Stream.error(const StorageFailure()));
        final cubit = buildCubit(
          clock: Clock(() => lateEvening.add(async.elapsed)),
        )..watch();
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 2));
        cubit.appResumed();

        expect(cubit.state, const HomeFailure(StorageFailure()));
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('closing stops the midnight timer', () {
      fakeAsync((async) {
        when(() => watchProgress()).thenAnswer((_) => const Stream.empty());
        final cubit = buildCubit(clock: Clock(() => lateEvening))..watch();
        expect(async.pendingTimers, hasLength(1));

        unawaited(cubit.close());
        async.flushMicrotasks();

        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
