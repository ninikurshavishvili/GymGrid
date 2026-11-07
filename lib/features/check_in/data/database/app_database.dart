import 'package:drift/drift.dart';

import '../../../../core/date/calendar_day.dart';
import '../../domain/entities/other_activity.dart';
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
  ///
  /// Version 2 let a check-in hold several photos, and version 3 added the
  /// activity of an Other workout.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Rebuilds the table, turning each row's one `photo_path` into a
        // list holding it, so existing check-ins keep their photos.
        //
        // The rebuilt table has the current shape, so it already has every
        // column added since version 2. They're listed as new, which leaves
        // them empty, and the later steps below are skipped.
        await migrator.alterTable(
          TableMigration(
            checkIns,
            columnTransformer: {
              checkIns.photoPaths: const CustomExpression<String>(
                'json_array(photo_path)',
              ),
            },
            newColumns: [checkIns.photoPaths, checkIns.activity],
          ),
        );
        return;
      }
      if (from < 3) {
        // Existing check-ins have no activity, so the column starts empty.
        await migrator.addColumn(checkIns, checkIns.activity);
      }
    },
  );
}
