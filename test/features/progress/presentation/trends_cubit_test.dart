import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/progress/domain/entities/trends.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_trends.dart';
import 'package:gym_grid/features/progress/presentation/trends_cubit.dart';
import 'package:gym_grid/features/progress/presentation/trends_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchTrends extends Mock implements WatchTrends {}

void main() {
  late _MockWatchTrends watchTrends;
  late Map<TrendRange, StreamController<Trends>> streams;

  final today = CalendarDay(2026, 11, 7);
  Trends trendsFor(TrendRange range) =>
      Trends.from(const [], range: range, today: today);

  setUpAll(() => registerFallbackValue(TrendRange.month));

  setUp(() {
    watchTrends = _MockWatchTrends();
    streams = {
      for (final range in TrendRange.values)
        range: StreamController<Trends>.broadcast(),
    };
    for (final MapEntry(key: range, value: stream) in streams.entries) {
      addTearDown(stream.close);
      when(() => watchTrends(range)).thenAnswer((_) => stream.stream);
    }
  });

  TrendsCubit buildCubit() => TrendsCubit(watchTrends: watchTrends);

  test('starts loading the past month, with both lines shown', () {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    expect(cubit.state, const TrendsState());
    expect(cubit.state.range, TrendRange.month);
    expect(cubit.state.showsEffort, isTrue);
    expect(cubit.state.showsEnergy, isTrue);
  });

  blocTest<TrendsCubit, TrendsState>(
    'shows the trends as they arrive',
    build: buildCubit,
    act: (cubit) async {
      cubit.watch();
      streams[TrendRange.month]!.add(trendsFor(TrendRange.month));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      TrendsState(
        status: TrendsStatus.loaded,
        trends: trendsFor(TrendRange.month),
      ),
    ],
  );

  blocTest<TrendsCubit, TrendsState>(
    'a new range follows its own trends, and keeps the old ones on screen '
    'until they arrive',
    build: buildCubit,
    seed: () => TrendsState(
      status: TrendsStatus.loaded,
      trends: trendsFor(TrendRange.month),
    ),
    act: (cubit) async {
      cubit.selectRange(TrendRange.year);
      streams[TrendRange.month]!.add(trendsFor(TrendRange.month));
      streams[TrendRange.year]!.add(trendsFor(TrendRange.year));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      TrendsState(
        range: TrendRange.year,
        status: TrendsStatus.loaded,
        trends: trendsFor(TrendRange.month),
      ),
      TrendsState(
        range: TrendRange.year,
        status: TrendsStatus.loaded,
        trends: trendsFor(TrendRange.year),
      ),
    ],
    verify: (_) => verify(() => watchTrends(TrendRange.year)).called(1),
  );

  blocTest<TrendsCubit, TrendsState>(
    'choosing the range already shown does nothing',
    build: buildCubit,
    act: (cubit) => cubit.selectRange(TrendRange.month),
    expect: () => <TrendsState>[],
    verify: (_) => verifyNever(() => watchTrends(any())),
  );

  blocTest<TrendsCubit, TrendsState>(
    'hides and shows each line',
    build: buildCubit,
    act: (cubit) => cubit
      ..toggleEffort()
      ..toggleEffort()
      ..toggleEnergy(),
    expect: () => const [
      TrendsState(showsEffort: false),
      TrendsState(),
      TrendsState(showsEnergy: false),
    ],
  );

  blocTest<TrendsCubit, TrendsState>(
    'keeps the last line showing',
    build: buildCubit,
    seed: () => const TrendsState(showsEnergy: false),
    act: (cubit) => cubit.toggleEffort(),
    expect: () => <TrendsState>[],
  );

  blocTest<TrendsCubit, TrendsState>(
    'keeps the last line showing, whichever it is',
    build: buildCubit,
    seed: () => const TrendsState(showsEffort: false),
    act: (cubit) => cubit.toggleEnergy(),
    expect: () => <TrendsState>[],
  );

  blocTest<TrendsCubit, TrendsState>(
    'a storage failure shows as one, and trying again reloads',
    build: buildCubit,
    act: (cubit) async {
      cubit.watch();
      streams[TrendRange.month]!.addError(const StorageFailure());
      await Future<void>.delayed(Duration.zero);
      cubit.watch();
      streams[TrendRange.month]!.add(trendsFor(TrendRange.month));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const TrendsState(status: TrendsStatus.failure),
      const TrendsState(),
      TrendsState(
        status: TrendsStatus.loaded,
        trends: trendsFor(TrendRange.month),
      ),
    ],
  );

  test('stops following the trends when closed', () async {
    final cubit = buildCubit()..watch();
    expect(streams[TrendRange.month]!.hasListener, isTrue);

    await cubit.close();

    expect(streams[TrendRange.month]!.hasListener, isFalse);
  });
}
