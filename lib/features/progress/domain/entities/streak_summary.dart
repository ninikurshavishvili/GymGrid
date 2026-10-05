import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../../../core/date/calendar_day.dart';

/// The current and longest runs of consecutive check-in days.
class StreakSummary extends Equatable {
  const StreakSummary({
    required this.current,
    required this.longest,
    required this.isAtRisk,
  });

  /// Calculates streaks from the days that have a check-in, as of [today].
  ///
  /// [checkInDays] may be in any order and contain duplicates. Days after
  /// [today], which appear only if the device clock was moved back, don't
  /// count toward the current streak.
  factory StreakSummary.from(
    Iterable<CalendarDay> checkInDays, {
    required CalendarDay today,
  }) {
    final days = checkInDays.toSet();
    final yesterday = today.addDays(-1);
    final checkedInToday = days.contains(today);

    // A day without a check-in only breaks the streak once it's over, so
    // until today's check-in the streak counts back from yesterday.
    var current = 0;
    var day = checkedInToday ? today : yesterday;
    while (days.contains(day)) {
      current++;
      day = day.addDays(-1);
    }

    return StreakSummary(
      current: current,
      longest: _longestRun(days),
      isAtRisk: !checkedInToday && days.contains(yesterday),
    );
  }

  /// Days in the run that ends today, or yesterday if there's no check-in
  /// today yet. 0 once a whole day has passed without a check-in.
  final int current;

  /// Days in the longest run ever, including the current one.
  final int longest;

  /// Whether there was a check-in yesterday but none yet today, so the
  /// current streak ends at midnight unless the user checks in.
  final bool isAtRisk;

  static int _longestRun(Set<CalendarDay> days) {
    var longest = 0;
    for (final start in days) {
      // Measure each run once, from its first day.
      if (days.contains(start.addDays(-1))) continue;
      var length = 1;
      while (days.contains(start.addDays(length))) {
        length++;
      }
      longest = math.max(longest, length);
    }
    return longest;
  }

  @override
  List<Object> get props => [current, longest, isAtRisk];
}
