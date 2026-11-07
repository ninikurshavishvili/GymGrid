import 'package:equatable/equatable.dart';

import '../../../core/errors/failure.dart';
import '../domain/entities/history_month.dart';

/// What the history screen shows.
sealed class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => const [];
}

/// Waiting for the first list.
final class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

/// Every month with a check-in, newest first. Empty if there are none.
final class HistoryLoaded extends HistoryState {
  const HistoryLoaded(this.months);

  final List<HistoryMonth> months;

  @override
  List<Object?> get props => [months];
}

/// The check-ins couldn't be read. The user can try again.
final class HistoryFailure extends HistoryState {
  const HistoryFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
