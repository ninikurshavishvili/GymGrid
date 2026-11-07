import 'package:equatable/equatable.dart';

import '../../../check_in/domain/entities/check_in.dart';

/// One calendar month of check-ins, a section of the history list.
class HistoryMonth extends Equatable {
  const HistoryMonth({
    required this.year,
    required this.month,
    required this.checkIns,
  });

  HistoryMonth._of(List<CheckIn> checkIns)
    : year = checkIns.first.date.year,
      month = checkIns.first.date.month,
      checkIns = List.unmodifiable(checkIns);

  /// Groups [checkIns] by month: the newest month first, and the newest
  /// check-in first within each. Months without a check-in are left out.
  static List<HistoryMonth> group(Iterable<CheckIn> checkIns) {
    final newestFirst = checkIns.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final months = <HistoryMonth>[];
    var current = <CheckIn>[];
    for (final checkIn in newestFirst) {
      final first = current.firstOrNull;
      if (first != null &&
          (first.date.year != checkIn.date.year ||
              first.date.month != checkIn.date.month)) {
        months.add(HistoryMonth._of(current));
        current = [];
      }
      current.add(checkIn);
    }
    if (current.isNotEmpty) months.add(HistoryMonth._of(current));
    return months;
  }

  final int year;

  /// 1 for January, as in [DateTime].
  final int month;

  /// Never empty, newest first.
  final List<CheckIn> checkIns;

  @override
  List<Object?> get props => [year, month, checkIns];
}
