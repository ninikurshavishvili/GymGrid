import 'package:drift/drift.dart';

import 'converters.dart';

/// One row per check-in, and at most one per day.
///
/// The photos themselves are files; [photoPaths] locates them relative to
/// the app's documents directory. Keeping images out of SQLite keeps the
/// database small, like Core Data's "Allows External Storage".
///
/// Rows are named [CheckInRow] so they don't clash with the domain's
/// `CheckIn` entity, which the repository maps them to.
@DataClassName('CheckInRow')
class CheckIns extends Table {
  /// A UUID generated on the device.
  TextColumn get id => text()();

  /// Unique, so the database itself enforces one check-in per day.
  TextColumn get day => text().map(const CalendarDayConverter()).unique()();

  /// A JSON list rather than a second table: the paths are only ever read
  /// and written together with their check-in, cover first.
  TextColumn get photoPaths => text().map(const PhotoPathsConverter())();

  TextColumn get workoutType => text().map(const WorkoutTypeConverter())();

  /// Only ever set for an Other workout. Added in schema version 3.
  TextColumn get activity =>
      text().map(const OtherActivityConverter()).nullable()();

  TextColumn get note => text().nullable()();

  /// How hard the workout was, as a percentage. Added in schema version 4.
  IntColumn get effort => integer().map(const RatingConverter()).nullable()();

  /// How much energy the user had, as a percentage. Added in schema
  /// version 4.
  IntColumn get energy => integer().map(const RatingConverter()).nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
