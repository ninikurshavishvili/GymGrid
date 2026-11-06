import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failure.dart';
import '../../check_in/domain/entities/check_in.dart';
import '../../check_in/presentation/photo_picker.dart';

/// What the day detail screen is busy with.
enum DayDetailActivity { idle, addingPhoto, deleting }

/// An action that didn't work, for the screen to explain.
enum DayDetailError { photoNotSaved, notDeleted }

/// What the day detail screen shows.
sealed class DayDetailState extends Equatable {
  const DayDetailState();

  @override
  List<Object?> get props => const [];
}

final class DayDetailLoading extends DayDetailState {
  const DayDetailLoading();
}

final class DayDetailLoaded extends DayDetailState {
  const DayDetailLoaded(
    this.checkIn, {
    this.activity = DayDetailActivity.idle,
    this.photoProblem,
    this.error,
  });

  final CheckIn checkIn;
  final DayDetailActivity activity;
  final PhotoProblem? photoProblem;
  final DayDetailError? error;

  bool get isBusy => activity != DayDetailActivity.idle;

  bool get canAddPhoto => checkIn.photoPaths.length < CheckIn.maxPhotos;

  /// The two message fields are functions so that `() => null` can clear
  /// them, which plain nullable parameters couldn't tell from leaving them
  /// out.
  DayDetailLoaded copyWith({
    CheckIn? checkIn,
    DayDetailActivity? activity,
    ValueGetter<PhotoProblem?>? photoProblem,
    ValueGetter<DayDetailError?>? error,
  }) {
    return DayDetailLoaded(
      checkIn ?? this.checkIn,
      activity: activity ?? this.activity,
      photoProblem: photoProblem == null ? this.photoProblem : photoProblem(),
      error: error == null ? this.error : error(),
    );
  }

  @override
  List<Object?> get props => [checkIn, activity, photoProblem, error];
}

/// There's no check-in on this day, as after following an old link.
final class DayDetailNotFound extends DayDetailState {
  const DayDetailNotFound();
}

/// The check-in couldn't be read. The user can try again.
final class DayDetailFailure extends DayDetailState {
  const DayDetailFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// The check-in was deleted, so the screen should close.
final class DayDetailDeleted extends DayDetailState {
  const DayDetailDeleted();
}
