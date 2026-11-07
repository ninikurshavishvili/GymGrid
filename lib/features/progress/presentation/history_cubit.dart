import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../domain/entities/history_month.dart';
import '../domain/usecases/watch_history.dart';
import 'history_state.dart';

/// Keeps the history screen's list of check-ins current.
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({required WatchHistory watchHistory})
    : _watchHistory = watchHistory,
      super(const HistoryLoading());

  final WatchHistory _watchHistory;
  StreamSubscription<List<HistoryMonth>>? _subscription;

  /// Starts following the check-ins, or starts again after a failure.
  void watch() {
    unawaited(_subscription?.cancel());

    if (state is! HistoryLoading) emit(const HistoryLoading());
    _subscription = _watchHistory().listen(
      (months) => emit(HistoryLoaded(months)),
      onError: _onError,
    );
  }

  /// Anything other than a [Failure] is a bug, so it's rethrown rather than
  /// shown as a message.
  void _onError(Object error, StackTrace stackTrace) {
    if (error is! Failure) Error.throwWithStackTrace(error, stackTrace);
    emit(HistoryFailure(error));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
