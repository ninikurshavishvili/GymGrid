import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../domain/entities/progress.dart';
import '../domain/usecases/watch_progress.dart';
import 'home_state.dart';

/// Keeps the home screen up to date with the user's progress.
///
/// A Cubit is close to an `ObservableObject` view model with a single
/// published `state`. The stream does the updating: saving a check-in on
/// another screen reaches this Cubit through the database, so nothing has
/// to tell the home screen to refresh.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required WatchProgress watchProgress})
    : _watchProgress = watchProgress,
      super(const HomeLoading());

  final WatchProgress _watchProgress;
  StreamSubscription<Progress>? _subscription;

  /// Starts following the user's progress, replacing any earlier
  /// subscription. Also what "Try again" calls after a failure.
  ///
  /// Deliberately not `async`: a subscription stops delivering events as
  /// soon as `cancel` is called, so there's nothing to wait for, and with
  /// no gap here [close] can't run between cancelling and subscribing.
  void watch() {
    unawaited(_subscription?.cancel());

    if (state is! HomeLoading) emit(const HomeLoading());
    _subscription = _watchProgress().listen(
      (progress) => emit(HomeLoaded(progress)),
      onError: _onError,
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    // The repository reports every storage error as a Failure, so anything
    // else is a bug and should surface as one, not as a "Try again" screen.
    if (error is! Failure) Error.throwWithStackTrace(error, stackTrace);
    emit(HomeFailure(error));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
