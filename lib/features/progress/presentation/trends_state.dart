import 'package:equatable/equatable.dart';

import '../domain/entities/trends.dart';

/// Where the Trends screen is in loading its data.
enum TrendsStatus { loading, loaded, failure }

/// The Trends screen: the range chosen, its data, and which lines show.
///
/// One class rather than a sealed set like `HomeState`, because the range
/// and the shown lines outlast a reload.
class TrendsState extends Equatable {
  const TrendsState({
    this.range = TrendRange.month,
    this.status = TrendsStatus.loading,
    this.trends,
    this.showsEffort = true,
    this.showsEnergy = true,
  });

  /// The range the user chose. Right after a change, [trends] can still be
  /// the previous range's for a moment, which keeps the chart from flashing
  /// empty.
  final TrendRange range;

  final TrendsStatus status;

  /// Null until the first data arrives.
  final Trends? trends;

  final bool showsEffort;
  final bool showsEnergy;

  TrendsState copyWith({
    TrendRange? range,
    TrendsStatus? status,
    Trends? trends,
    bool? showsEffort,
    bool? showsEnergy,
  }) {
    return TrendsState(
      range: range ?? this.range,
      status: status ?? this.status,
      trends: trends ?? this.trends,
      showsEffort: showsEffort ?? this.showsEffort,
      showsEnergy: showsEnergy ?? this.showsEnergy,
    );
  }

  @override
  List<Object?> get props => [range, status, trends, showsEffort, showsEnergy];
}
