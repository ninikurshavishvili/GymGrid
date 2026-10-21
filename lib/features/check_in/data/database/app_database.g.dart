// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CheckInsTable extends CheckIns
    with TableInfo<$CheckInsTable, CheckInRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CalendarDay, String> day =
      GeneratedColumn<String>(
        'day',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
      ).withConverter<CalendarDay>($CheckInsTable.$converterday);
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<WorkoutType, String> workoutType =
      GeneratedColumn<String>(
        'workout_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<WorkoutType>($CheckInsTable.$converterworkoutType);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    day,
    photoPath,
    workoutType,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'check_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<CheckInRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    } else if (isInserting) {
      context.missing(_photoPathMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CheckInRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckInRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      day: $CheckInsTable.$converterday.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}day'],
        )!,
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      )!,
      workoutType: $CheckInsTable.$converterworkoutType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}workout_type'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CheckInsTable createAlias(String alias) {
    return $CheckInsTable(attachedDatabase, alias);
  }

  static TypeConverter<CalendarDay, String> $converterday =
      const CalendarDayConverter();
  static TypeConverter<WorkoutType, String> $converterworkoutType =
      const WorkoutTypeConverter();
}

class CheckInRow extends DataClass implements Insertable<CheckInRow> {
  /// A UUID generated on the device.
  final String id;

  /// Unique, so the database itself enforces one check-in per day.
  final CalendarDay day;
  final String photoPath;
  final WorkoutType workoutType;
  final String? note;
  final DateTime createdAt;
  const CheckInRow({
    required this.id,
    required this.day,
    required this.photoPath,
    required this.workoutType,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['day'] = Variable<String>($CheckInsTable.$converterday.toSql(day));
    }
    map['photo_path'] = Variable<String>(photoPath);
    {
      map['workout_type'] = Variable<String>(
        $CheckInsTable.$converterworkoutType.toSql(workoutType),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CheckInsCompanion toCompanion(bool nullToAbsent) {
    return CheckInsCompanion(
      id: Value(id),
      day: Value(day),
      photoPath: Value(photoPath),
      workoutType: Value(workoutType),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory CheckInRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckInRow(
      id: serializer.fromJson<String>(json['id']),
      day: serializer.fromJson<CalendarDay>(json['day']),
      photoPath: serializer.fromJson<String>(json['photoPath']),
      workoutType: serializer.fromJson<WorkoutType>(json['workoutType']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'day': serializer.toJson<CalendarDay>(day),
      'photoPath': serializer.toJson<String>(photoPath),
      'workoutType': serializer.toJson<WorkoutType>(workoutType),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CheckInRow copyWith({
    String? id,
    CalendarDay? day,
    String? photoPath,
    WorkoutType? workoutType,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => CheckInRow(
    id: id ?? this.id,
    day: day ?? this.day,
    photoPath: photoPath ?? this.photoPath,
    workoutType: workoutType ?? this.workoutType,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  CheckInRow copyWithCompanion(CheckInsCompanion data) {
    return CheckInRow(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      workoutType: data.workoutType.present
          ? data.workoutType.value
          : this.workoutType,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckInRow(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('photoPath: $photoPath, ')
          ..write('workoutType: $workoutType, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, day, photoPath, workoutType, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckInRow &&
          other.id == this.id &&
          other.day == this.day &&
          other.photoPath == this.photoPath &&
          other.workoutType == this.workoutType &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class CheckInsCompanion extends UpdateCompanion<CheckInRow> {
  final Value<String> id;
  final Value<CalendarDay> day;
  final Value<String> photoPath;
  final Value<WorkoutType> workoutType;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CheckInsCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.workoutType = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CheckInsCompanion.insert({
    required String id,
    required CalendarDay day,
    required String photoPath,
    required WorkoutType workoutType,
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       day = Value(day),
       photoPath = Value(photoPath),
       workoutType = Value(workoutType),
       createdAt = Value(createdAt);
  static Insertable<CheckInRow> custom({
    Expression<String>? id,
    Expression<String>? day,
    Expression<String>? photoPath,
    Expression<String>? workoutType,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (photoPath != null) 'photo_path': photoPath,
      if (workoutType != null) 'workout_type': workoutType,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CheckInsCompanion copyWith({
    Value<String>? id,
    Value<CalendarDay>? day,
    Value<String>? photoPath,
    Value<WorkoutType>? workoutType,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CheckInsCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      photoPath: photoPath ?? this.photoPath,
      workoutType: workoutType ?? this.workoutType,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(
        $CheckInsTable.$converterday.toSql(day.value),
      );
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (workoutType.present) {
      map['workout_type'] = Variable<String>(
        $CheckInsTable.$converterworkoutType.toSql(workoutType.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckInsCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('photoPath: $photoPath, ')
          ..write('workoutType: $workoutType, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CheckInsTable checkIns = $CheckInsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [checkIns];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CheckInsTableCreateCompanionBuilder =
    CheckInsCompanion Function({
      required String id,
      required CalendarDay day,
      required String photoPath,
      required WorkoutType workoutType,
      Value<String?> note,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$CheckInsTableUpdateCompanionBuilder =
    CheckInsCompanion Function({
      Value<String> id,
      Value<CalendarDay> day,
      Value<String> photoPath,
      Value<WorkoutType> workoutType,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$CheckInsTableFilterComposer
    extends Composer<_$AppDatabase, $CheckInsTable> {
  $$CheckInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CalendarDay, CalendarDay, String> get day =>
      $composableBuilder(
        column: $table.day,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<WorkoutType, WorkoutType, String>
  get workoutType => $composableBuilder(
    column: $table.workoutType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CheckInsTableOrderingComposer
    extends Composer<_$AppDatabase, $CheckInsTable> {
  $$CheckInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workoutType => $composableBuilder(
    column: $table.workoutType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CheckInsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheckInsTable> {
  $$CheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CalendarDay, String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumnWithTypeConverter<WorkoutType, String> get workoutType =>
      $composableBuilder(
        column: $table.workoutType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CheckInsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CheckInsTable,
          CheckInRow,
          $$CheckInsTableFilterComposer,
          $$CheckInsTableOrderingComposer,
          $$CheckInsTableAnnotationComposer,
          $$CheckInsTableCreateCompanionBuilder,
          $$CheckInsTableUpdateCompanionBuilder,
          (
            CheckInRow,
            BaseReferences<_$AppDatabase, $CheckInsTable, CheckInRow>,
          ),
          CheckInRow,
          PrefetchHooks Function()
        > {
  $$CheckInsTableTableManager(_$AppDatabase db, $CheckInsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<CalendarDay> day = const Value.absent(),
                Value<String> photoPath = const Value.absent(),
                Value<WorkoutType> workoutType = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CheckInsCompanion(
                id: id,
                day: day,
                photoPath: photoPath,
                workoutType: workoutType,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required CalendarDay day,
                required String photoPath,
                required WorkoutType workoutType,
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CheckInsCompanion.insert(
                id: id,
                day: day,
                photoPath: photoPath,
                workoutType: workoutType,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CheckInsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CheckInsTable,
      CheckInRow,
      $$CheckInsTableFilterComposer,
      $$CheckInsTableOrderingComposer,
      $$CheckInsTableAnnotationComposer,
      $$CheckInsTableCreateCompanionBuilder,
      $$CheckInsTableUpdateCompanionBuilder,
      (CheckInRow, BaseReferences<_$AppDatabase, $CheckInsTable, CheckInRow>),
      CheckInRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CheckInsTableTableManager get checkIns =>
      $$CheckInsTableTableManager(_db, _db.checkIns);
}
