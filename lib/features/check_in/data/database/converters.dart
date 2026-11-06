import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/date/calendar_day.dart';
import '../../domain/entities/workout_type.dart';

/// Stores a [CalendarDay] as `yyyy-MM-dd` text, which also sorts by date.
class CalendarDayConverter extends TypeConverter<CalendarDay, String> {
  const CalendarDayConverter();

  @override
  CalendarDay fromSql(String fromDb) =>
      CalendarDay.tryParse(fromDb) ??
      (throw FormatException('Not a yyyy-MM-dd day', fromDb));

  @override
  String toSql(CalendarDay value) => value.toIso8601String();
}

/// Stores a check-in's photo paths as a JSON list.
class PhotoPathsConverter extends TypeConverter<List<String>, String> {
  const PhotoPathsConverter();

  @override
  List<String> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);
    if (decoded is! List<dynamic> || decoded.isEmpty) {
      throw FormatException('Not a list of photo paths', fromDb);
    }
    return List.unmodifiable(decoded.cast<String>());
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Stores a [WorkoutType] as fixed text.
///
/// The text is spelled out rather than taken from the enum value's `name`,
/// so renaming a Dart value can't strand rows saved under the old name:
/// the switches below stop compiling instead, and the stored text can be
/// kept as it was.
class WorkoutTypeConverter extends TypeConverter<WorkoutType, String> {
  const WorkoutTypeConverter();

  @override
  WorkoutType fromSql(String fromDb) => switch (fromDb) {
    'strength' => WorkoutType.strength,
    'cardio' => WorkoutType.cardio,
    'mobility' => WorkoutType.mobility,
    'other' => WorkoutType.other,
    _ => throw FormatException('Unknown workout type', fromDb),
  };

  @override
  String toSql(WorkoutType value) => switch (value) {
    WorkoutType.strength => 'strength',
    WorkoutType.cardio => 'cardio',
    WorkoutType.mobility => 'mobility',
    WorkoutType.other => 'other',
  };
}
