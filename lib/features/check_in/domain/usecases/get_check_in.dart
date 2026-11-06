import '../../../../core/date/calendar_day.dart';
import '../../../../core/errors/failure.dart';
import '../entities/check_in.dart';
import '../repositories/check_in_repository.dart';

/// Looks up the check-in for a day.
class GetCheckIn {
  const GetCheckIn({required CheckInRepository repository})
    : _repository = repository;

  final CheckInRepository _repository;

  /// The check-in for [date], or null if there is none. Throws a [Failure]
  /// if it can't be read.
  Future<CheckIn?> call(CalendarDay date) => _repository.findByDate(date);
}
