import 'package:equatable/equatable.dart';

import '../../../core/errors/failure.dart';
import '../domain/entities/progress.dart';

/// What the home screen shows. Sealed, so a `switch` over it must handle
/// every case, like a Swift `enum` with associated values.
sealed class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => const [];
}

/// Waiting for the first [Progress].
final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeLoaded extends HomeState {
  const HomeLoaded(this.progress);

  final Progress progress;

  @override
  List<Object?> get props => [progress];
}

/// The check-ins couldn't be read. The user can try again.
final class HomeFailure extends HomeState {
  const HomeFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
