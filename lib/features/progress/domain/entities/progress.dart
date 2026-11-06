import 'package:equatable/equatable.dart';

import '../../../../core/date/calendar_day.dart';
import '../../../check_in/domain/entities/check_in.dart';
import 'streak_summary.dart';

/// The user's progress as of [today], worked out from their check-ins.
class Progress extends Equatable {
  const Progress({
    required this.checkIns,
    required this.today,
    required this.streaks,
    required this.checkInCountThisYear,
    this.todaysCheckIn,
  });

  /// Calculates progress from every check-in, as of [today].
  factory Progress.from(List<CheckIn> checkIns, {required CalendarDay today}) {
    final days = checkIns.map((checkIn) => checkIn.date);

    return Progress(
      checkIns: checkIns,
      today: today,
      streaks: StreakSummary.from(days, today: today),
      todaysCheckIn: checkIns
          .where((checkIn) => checkIn.date == today)
          .firstOrNull,
      checkInCountThisYear: days
          .where((day) => day.year == today.year && !day.isAfter(today))
          .length,
    );
  }

  /// Every check-in, oldest first.
  final List<CheckIn> checkIns;

  /// The day this progress was calculated for.
  final CalendarDay today;

  final StreakSummary streaks;

  /// Null until the user checks in today.
  final CheckIn? todaysCheckIn;

  /// Check-ins from 1 January up to [today].
  ///
  /// Days after [today], which appear only if the device clock was moved
  /// back, aren't counted, so this agrees with the year grid.
  final int checkInCountThisYear;

  @override
  List<Object?> get props => [
    checkIns,
    today,
    streaks,
    todaysCheckIn,
    checkInCountThisYear,
  ];
}
