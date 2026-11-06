import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../domain/entities/workout_type.dart';

/// Where the form is in saving a check-in.
enum CheckInStatus { editing, saving, failure, saved }

/// Why the last attempt to get a photo failed.
enum PhotoProblem { cameraUnavailable, libraryUnavailable }

/// The check-in form.
class CheckInState extends Equatable {
  const CheckInState({
    this.photoPath,
    this.workoutType,
    this.note = '',
    this.status = CheckInStatus.editing,
    this.photoProblem,
    this.isPickingPhoto = false,
    this.isReplacingToday = false,
  });

  /// The picked photo's temporary file, until it's saved.
  final String? photoPath;

  final WorkoutType? workoutType;
  final String note;
  final CheckInStatus status;
  final PhotoProblem? photoProblem;

  /// Whether a picker is open or still preparing its photo, which takes a
  /// moment after it closes.
  final bool isPickingPhoto;

  /// Whether today already has a check-in, which saving would replace.
  final bool isReplacingToday;

  bool get isSaving => status == CheckInStatus.saving;

  bool get canSave =>
      photoPath != null && workoutType != null && !isSaving && !isPickingPhoto;

  /// Whether leaving now would lose something worth asking about. Choosing a
  /// workout type alone isn't: it takes one tap to do again.
  bool get hasDraft => photoPath != null || note.trim().isNotEmpty;

  /// [photoProblem] is a function so that passing `() => null` can clear it,
  /// which a plain nullable parameter couldn't tell apart from leaving it
  /// out.
  CheckInState copyWith({
    String? photoPath,
    WorkoutType? workoutType,
    String? note,
    CheckInStatus? status,
    ValueGetter<PhotoProblem?>? photoProblem,
    bool? isPickingPhoto,
    bool? isReplacingToday,
  }) {
    return CheckInState(
      photoPath: photoPath ?? this.photoPath,
      workoutType: workoutType ?? this.workoutType,
      note: note ?? this.note,
      status: status ?? this.status,
      photoProblem: photoProblem == null ? this.photoProblem : photoProblem(),
      isPickingPhoto: isPickingPhoto ?? this.isPickingPhoto,
      isReplacingToday: isReplacingToday ?? this.isReplacingToday,
    );
  }

  @override
  List<Object?> get props => [
    photoPath,
    workoutType,
    note,
    status,
    photoProblem,
    isPickingPhoto,
    isReplacingToday,
  ];
}
