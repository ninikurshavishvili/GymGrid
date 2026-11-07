import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/progress/domain/entities/history_month.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_history.dart';
import 'package:gym_grid/features/progress/presentation/history_cubit.dart';
import 'package:gym_grid/features/progress/presentation/history_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchHistory extends Mock implements WatchHistory {}

void main() {
  late _MockWatchHistory watchHistory;
  late StreamController<List<HistoryMonth>> history;

  final november = [
    HistoryMonth(
      year: 2026,
      month: 11,
      checkIns: [
        CheckIn(
          id: '1',
          date: CalendarDay(2026, 11, 6),
          photoPaths: const ['photos/1.jpg'],
          workoutType: WorkoutType.strength,
          createdAt: DateTime(2026, 11, 6, 7, 42),
        ),
      ],
    ),
  ];

  setUp(() {
    watchHistory = _MockWatchHistory();
    history = StreamController<List<HistoryMonth>>.broadcast();
    addTearDown(history.close);
    when(() => watchHistory()).thenAnswer((_) => history.stream);
  });

  HistoryCubit buildCubit() => HistoryCubit(watchHistory: watchHistory);

  test('starts loading', () {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    expect(cubit.state, const HistoryLoading());
  });

  blocTest<HistoryCubit, HistoryState>(
    'shows each list as it arrives',
    build: buildCubit,
    act: (cubit) async {
      cubit.watch();
      history
        ..add(const [])
        ..add(november);
    },
    expect: () => [const HistoryLoaded([]), HistoryLoaded(november)],
  );

  blocTest<HistoryCubit, HistoryState>(
    'shows a failure',
    build: buildCubit,
    act: (cubit) async {
      cubit.watch();
      history.addError(const StorageFailure());
    },
    expect: () => [const HistoryFailure(StorageFailure())],
  );

  blocTest<HistoryCubit, HistoryState>(
    'trying again after a failure starts over',
    build: buildCubit,
    seed: () => const HistoryFailure(StorageFailure()),
    act: (cubit) async {
      cubit.watch();
      history.add(november);
    },
    expect: () => [const HistoryLoading(), HistoryLoaded(november)],
  );

  test('stops listening once closed', () async {
    final cubit = buildCubit()..watch();
    expect(history.hasListener, isTrue);

    await cubit.close();

    expect(history.hasListener, isFalse);
  });
}
