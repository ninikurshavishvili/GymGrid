import '../../../../core/errors/failure.dart';
import '../../../check_in/domain/repositories/check_in_repository.dart';
import '../entities/history_month.dart';

/// Streams every check-in there has been, grouped by month, so the history
/// screen updates by itself when one is edited or deleted.
class WatchHistory {
  const WatchHistory({required CheckInRepository repository})
    : _repository = repository;

  final CheckInRepository _repository;

  /// Emits the months with check-ins, newest first, then again after each
  /// change. Errors on the stream are [Failure]s.
  Stream<List<HistoryMonth>> call() =>
      _repository.watchAll().map(HistoryMonth.group);
}
