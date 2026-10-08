import 'package:drift/drift.dart';

import '../../../../core/date/calendar_day.dart';
import '../../domain/entities/workout_type.dart';
import 'check_ins_table.dart';
import 'converters.dart';

part 'app_database.g.dart';

/// The app's SQLite database.
///
/// The caller supplies the connection: a file in Application Support in the
/// app, or an in-memory database in tests.
@DriftDatabase(tables: [CheckIns])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Increase this when a table changes, then run
  /// `dart run drift_dev make-migrations` and write the migration step.
  @override
  int get schemaVersion => 1;
}
