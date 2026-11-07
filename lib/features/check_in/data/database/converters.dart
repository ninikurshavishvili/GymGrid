import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/date/calendar_day.dart';
import '../../domain/entities/other_activity.dart';
import '../../domain/entities/rating.dart';
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

/// Stores an [OtherActivity] as fixed text, for the same reason as
/// [WorkoutTypeConverter].
class OtherActivityConverter extends TypeConverter<OtherActivity, String> {
  const OtherActivityConverter();

  @override
  OtherActivity fromSql(String fromDb) => switch (fromDb) {
    'class' => OtherActivity.groupClass,
    'sport' => OtherActivity.sport,
    'walk' => OtherActivity.walk,
    _ => throw FormatException('Unknown activity', fromDb),
  };

  @override
  String toSql(OtherActivity value) => switch (value) {
    OtherActivity.groupClass => 'class',
    OtherActivity.sport => 'sport',
    OtherActivity.walk => 'walk',
  };
}

/// Stores a [Rating] as its percentage, a whole number.
///
/// A percentage rather than a step number (1 to 5), so finer steps could be
/// added later without changing rows already saved. The numbers are spelled
/// out here, rather than read from [Rating.percent], for the same reason as
/// [WorkoutTypeConverter]: changing the enum can't silently change what's
/// on disk.
class RatingConverter extends TypeConverter<Rating, int> {
  const RatingConverter();

  @override
  Rating fromSql(int fromDb) => switch (fromDb) {
    20 => Rating.veryLow,
    40 => Rating.low,
    60 => Rating.medium,
    80 => Rating.high,
    100 => Rating.max,
    _ => throw FormatException('Unknown rating', fromDb),
  };

  @override
  int toSql(Rating value) => switch (value) {
    Rating.veryLow => 20,
    Rating.low => 40,
    Rating.medium => 60,
    Rating.high => 80,
    Rating.max => 100,
  };
}
