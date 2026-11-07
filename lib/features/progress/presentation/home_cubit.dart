import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/date/clock.dart';
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
///
/// The one thing the database can't announce is the date changing, which
/// moves "today", the streak and the at-risk state. So this also follows the
/// clock: a timer for midnight while the app is open, and [appResumed] for
/// when it wasn't.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required WatchProgress watchProgress, required Clock clock})
    : _watchProgress = watchProgress,
      _clock = clock,
      super(const HomeLoading());

  final WatchProgress _watchProgress;
  final Clock _clock;
  StreamSubscription<Progress>? _subscription;
  Timer? _midnightTimer;

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
    _scheduleMidnightUpdate();
  }

  /// Catches up after time away, when the date, the clock or the time zone
  /// may have changed. iOS also suspends timers in the background, and a
  /// clock change moves midnight, so the timer is set afresh.
  void appResumed() {
    _updateToday();
    _scheduleMidnightUpdate();
  }

  void _scheduleMidnightUpdate() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer(_clock.untilTomorrow(), () {
      _updateToday();
      _scheduleMidnightUpdate();
    });
  }

  /// Recalculates for the current day from the check-ins already here, which
  /// needs no trip to the database and can't flash a loading state.
  void _updateToday() {
    final current = state;
    if (current is! HomeLoaded) return;

    final today = _clock.today();
    if (today == current.progress.today) return;
    emit(HomeLoaded(Progress.from(current.progress.checkIns, today: today)));
  }

  void _onError(Object error, StackTrace stackTrace) {
    // The repository reports every storage error as a Failure, so anything
    // else is a bug and should surface as one, not as a "Try again" screen.
    if (error is! Failure) Error.throwWithStackTrace(error, stackTrace);
    emit(HomeFailure(error));
  }

  @override
  Future<void> close() async {
    _midnightTimer?.cancel();
    await _subscription?.cancel();
    return super.close();
  }
}
