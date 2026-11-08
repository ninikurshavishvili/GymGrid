import '../../../../core/date/clock.dart';
import '../../../../core/errors/failure.dart';
import '../../../check_in/domain/repositories/check_in_repository.dart';
import '../entities/trends.dart';

/// Streams the [Trends] for a range, so the chart updates by itself when a
/// check-in is rated, edited or deleted.
class WatchTrends {
  const WatchTrends({
    required CheckInRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final CheckInRepository _repository;
  final Clock _clock;

  /// Emits the trends over [range], ending today, then again after each
  /// change to the check-ins. Errors on the stream are [Failure]s.
  Stream<Trends> call(TrendRange range) => _repository.watchAll().map(
    (checkIns) => Trends.from(checkIns, range: range, today: _clock.today()),
  );
}
