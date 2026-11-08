import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../domain/entities/trends.dart';
import '../domain/usecases/watch_trends.dart';
import 'trends_state.dart';

/// Keeps the Trends screen's chart current for the chosen range.
class TrendsCubit extends Cubit<TrendsState> {
  TrendsCubit({required WatchTrends watchTrends})
    : _watchTrends = watchTrends,
      super(const TrendsState());

  final WatchTrends _watchTrends;
  StreamSubscription<Trends>? _subscription;

  /// Starts following the trends for the chosen range, replacing any
  /// earlier subscription. Also what "Try again" calls after a failure.
  void watch() {
    unawaited(_subscription?.cancel());

    if (state.status == TrendsStatus.failure) {
      emit(state.copyWith(status: TrendsStatus.loading));
    }
    _subscription = _watchTrends(state.range).listen(
      (trends) =>
          emit(state.copyWith(status: TrendsStatus.loaded, trends: trends)),
      onError: _onError,
    );
  }

  void selectRange(TrendRange range) {
    if (range == state.range) return;
    emit(state.copyWith(range: range));
    watch();
  }

  /// Shows or hides the effort line. The last line showing stays, so the
  /// chart can't be emptied by accident.
  void toggleEffort() {
    if (state.showsEffort && !state.showsEnergy) return;
    emit(state.copyWith(showsEffort: !state.showsEffort));
  }

  /// Shows or hides the energy line, like [toggleEffort].
  void toggleEnergy() {
    if (state.showsEnergy && !state.showsEffort) return;
    emit(state.copyWith(showsEnergy: !state.showsEnergy));
  }

  /// Anything other than a [Failure] is a bug, so it's rethrown rather than
  /// shown as a message.
  void _onError(Object error, StackTrace stackTrace) {
    if (error is! Failure) Error.throwWithStackTrace(error, stackTrace);
    emit(state.copyWith(status: TrendsStatus.failure));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
