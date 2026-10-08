import 'package:drift/drift.dart';

import 'converters.dart';

/// One row per check-in, and at most one per day.
///
/// The photo itself is a file; [photoPath] locates it relative to the app's
/// documents directory. Keeping images out of SQLite keeps the database
/// small, like Core Data's "Allows External Storage".
///
/// Rows are named [CheckInRow] so they don't clash with the domain's
/// `CheckIn` entity, which the repository maps them to.
@DataClassName('CheckInRow')
class CheckIns extends Table {
  /// A UUID generated on the device.
  TextColumn get id => text()();

  /// Unique, so the database itself enforces one check-in per day.
  TextColumn get day => text().map(const CalendarDayConverter()).unique()();

  TextColumn get photoPath => text()();

  TextColumn get workoutType => text().map(const WorkoutTypeConverter())();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
