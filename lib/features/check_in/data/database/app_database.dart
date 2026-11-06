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
  ///
  /// Version 2 let a check-in hold several photos.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Rebuilds the table, turning each row's one `photo_path` into a
        // list holding it, so existing check-ins keep their photos.
        await migrator.alterTable(
          TableMigration(
            checkIns,
            columnTransformer: {
              checkIns.photoPaths: const CustomExpression<String>(
                'json_array(photo_path)',
              ),
            },
            newColumns: [checkIns.photoPaths],
          ),
        );
      }
    },
  );
}
