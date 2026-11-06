import '../../../../core/date/calendar_day.dart';
import '../../../../core/errors/failure.dart';
import '../entities/check_in.dart';
import '../repositories/check_in_repository.dart';

/// Follows the check-in for one day, so a screen showing it stays current
/// when it's edited elsewhere.
class WatchCheckIn {
  const WatchCheckIn({required CheckInRepository repository})
    : _repository = repository;

  final CheckInRepository _repository;

  /// Emits the check-in for [date], or null if there is none, then again
  /// whenever that changes. Errors on the stream are [Failure]s.
  Stream<CheckIn?> call(CalendarDay date) {
    return _repository
        .watchAll()
        .map(
          (checkIns) =>
              checkIns.where((checkIn) => checkIn.date == date).firstOrNull,
        )
        .distinct();
  }
}
