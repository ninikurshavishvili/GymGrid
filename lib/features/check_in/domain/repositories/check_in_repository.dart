import '../../../../core/date/calendar_day.dart';
import '../../../../core/errors/failure.dart';
import '../entities/check_in.dart';
import '../entities/new_check_in.dart';

/// Stores check-ins, at most one per day.
///
/// The interface assumes nothing about where data lives. The app ships a
/// local implementation (SQLite and photo files), and a remote one could
/// replace it or sit behind it later. Like a Swift protocol, Cubits depend
/// on this type and never on an implementation; `abstract interface`
/// means it can only be implemented, not extended.
///
/// Every method throws a [Failure] when data can't be read or written.
abstract interface class CheckInRepository {
  /// Emits every check-in, oldest first, then again after each change.
  Stream<List<CheckIn>> watchAll();

  /// The check-in for [date], or null if there is none.
  Future<CheckIn?> findByDate(CalendarDay date);

  /// Stores [checkIn] and its photo, and returns the stored check-in.
  ///
  /// Replaces any existing check-in for the same date, including its photo.
  Future<CheckIn> save(NewCheckIn checkIn);

  /// Deletes the check-in with [id] and its photo. Does nothing if there is
  /// no such check-in.
  Future<void> delete(String id);
}
