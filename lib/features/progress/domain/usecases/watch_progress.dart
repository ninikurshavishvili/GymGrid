import '../../../../core/date/clock.dart';
import '../../../../core/errors/failure.dart';
import '../../../check_in/domain/repositories/check_in_repository.dart';
import '../entities/progress.dart';

/// Streams the user's [Progress], the way a Combine publisher would, so the
/// home screen updates on its own after every check-in.
class WatchProgress {
  const WatchProgress({
    required CheckInRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final CheckInRepository _repository;
  final Clock _clock;

  /// Emits the current progress, then again after each change to the
  /// check-ins. Errors on the stream are [Failure]s.
  ///
  /// Today is read for each emission, so nothing new is emitted when the
  /// date changes by itself. A subscriber that stays open past midnight
  /// has to recalculate for the new day, as `HomeCubit` does.
  Stream<Progress> call() => _repository.watchAll().map(
    (checkIns) => Progress.from(checkIns, today: _clock.today()),
  );
}
