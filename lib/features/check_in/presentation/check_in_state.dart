import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../domain/entities/check_in.dart';
import '../domain/entities/check_in_photo.dart';
import '../domain/entities/other_activity.dart';
import '../domain/entities/rating.dart';
import '../domain/entities/workout_type.dart';
import 'photo_picker.dart';

/// Where the form is in its work.
enum CheckInStatus { loading, loadFailed, editing, saving, failure, saved }

/// The check-in form, for a new check-in or an existing one.
class CheckInState extends Equatable {
  const CheckInState({
    this.isEditing = false,
    this.original,
    this.photos = const [],
    this.workoutType,
    this.activity,
    this.effort,
    this.energy,
    this.note = '',
    this.status = CheckInStatus.editing,
    this.photoProblem,
    this.isPickingPhoto = false,
  });

  /// Whether this edits an existing check-in rather than making a new one.
  final bool isEditing;

  /// The check-in being edited, once loaded.
  final CheckIn? original;

  /// The photos so far, cover first.
  final List<CheckInPhoto> photos;

  final WorkoutType? workoutType;

  /// Only ever set while [workoutType] is Other.
  final OtherActivity? activity;

  /// Null until the user rates it, which is optional.
  final Rating? effort;

  /// Null until the user rates it, which is optional.
  final Rating? energy;

  final String note;
  final CheckInStatus status;
  final PhotoProblem? photoProblem;

  /// Whether a picker is open or still preparing its photo, which takes a
  /// moment after it closes.
  final bool isPickingPhoto;

  bool get isSaving => status == CheckInStatus.saving;

  bool get canAddPhoto => photos.length < CheckIn.maxPhotos;

  bool get canSave =>
      photos.isNotEmpty &&
      workoutType != null &&
      !isSaving &&
      !isPickingPhoto &&
      (!isEditing || hasUnsavedChanges);

  /// Whether leaving now would lose something worth asking about. For a new
  /// check-in, choosing a workout type or a rating alone isn't: each takes
  /// one tap to do again.
  bool get hasUnsavedChanges {
    final original = this.original;
    if (original == null) return photos.isNotEmpty || note.trim().isNotEmpty;

    return !listEquals(photos, [
          for (final path in original.photoPaths) StoredPhoto(path),
        ]) ||
        workoutType != original.workoutType ||
        activity != original.activity ||
        effort != original.effort ||
        energy != original.energy ||
        CheckIn.cleanNote(note) != original.note;
  }

  /// [activity], [effort], [energy] and [photoProblem] are functions so
  /// that passing `() => null` can clear them, which a plain nullable
  /// parameter couldn't tell apart from leaving it out.
  CheckInState copyWith({
    CheckIn? original,
    List<CheckInPhoto>? photos,
    WorkoutType? workoutType,
    ValueGetter<OtherActivity?>? activity,
    ValueGetter<Rating?>? effort,
    ValueGetter<Rating?>? energy,
    String? note,
    CheckInStatus? status,
    ValueGetter<PhotoProblem?>? photoProblem,
    bool? isPickingPhoto,
  }) {
    return CheckInState(
      isEditing: isEditing,
      original: original ?? this.original,
      photos: photos ?? this.photos,
      workoutType: workoutType ?? this.workoutType,
      activity: activity == null ? this.activity : activity(),
      effort: effort == null ? this.effort : effort(),
      energy: energy == null ? this.energy : energy(),
      note: note ?? this.note,
      status: status ?? this.status,
      photoProblem: photoProblem == null ? this.photoProblem : photoProblem(),
      isPickingPhoto: isPickingPhoto ?? this.isPickingPhoto,
    );
  }

  @override
  List<Object?> get props => [
    isEditing,
    original,
    photos,
    workoutType,
    activity,
    effort,
    energy,
    note,
    status,
    photoProblem,
    isPickingPhoto,
  ];
}
