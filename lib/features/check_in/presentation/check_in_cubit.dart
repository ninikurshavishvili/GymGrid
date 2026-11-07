import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/date/calendar_day.dart';
import '../../../core/errors/failure.dart';
import '../domain/entities/check_in.dart';
import '../domain/entities/check_in_photo.dart';
import '../domain/entities/other_activity.dart';
import '../domain/entities/workout_type.dart';
import '../domain/usecases/get_check_in.dart';
import '../domain/usecases/save_check_in.dart';
import '../domain/usecases/update_check_in.dart';
import 'check_in_state.dart';
import 'photo_picker.dart';

/// Runs the check-in form: getting photos, filling it in, and saving.
///
/// Makes today's check-in, or edits the one on [editingDay] if that's given.
/// Both are the same form, so they can't drift apart.
class CheckInCubit extends Cubit<CheckInState> {
  CheckInCubit({
    required SaveCheckIn saveCheckIn,
    required UpdateCheckIn updateCheckIn,
    required GetCheckIn getCheckIn,
    required PhotoPicker photoPicker,
    CalendarDay? editingDay,
  }) : _saveCheckIn = saveCheckIn,
       _updateCheckIn = updateCheckIn,
       _getCheckIn = getCheckIn,
       _photoPicker = photoPicker,
       _editingDay = editingDay,
       super(
         editingDay == null
             ? const CheckInState()
             : const CheckInState(
                 isEditing: true,
                 status: CheckInStatus.loading,
               ),
       );

  final SaveCheckIn _saveCheckIn;
  final UpdateCheckIn _updateCheckIn;
  final GetCheckIn _getCheckIn;
  final PhotoPicker _photoPicker;
  final CalendarDay? _editingDay;

  /// Fills the form from the check-in being edited, if there is one.
  Future<void> load() async {
    final day = _editingDay;
    if (day == null) return;

    try {
      final checkIn = await _getCheckIn(day);
      if (isClosed) return;
      emit(
        checkIn == null
            ? state.copyWith(status: CheckInStatus.loadFailed)
            : state.copyWith(
                original: checkIn,
                photos: [
                  for (final path in checkIn.photoPaths) StoredPhoto(path),
                ],
                workoutType: checkIn.workoutType,
                activity: () => checkIn.activity,
                note: checkIn.note ?? '',
                status: CheckInStatus.editing,
              ),
      );
    } on Failure {
      if (isClosed) return;
      emit(state.copyWith(status: CheckInStatus.loadFailed));
    }
  }

  Future<void> takePhoto() =>
      _addPhoto(_photoPicker.takePhoto, PhotoProblem.cameraUnavailable);

  Future<void> pickFromLibrary() =>
      _addPhoto(_photoPicker.pickFromLibrary, PhotoProblem.libraryUnavailable);

  Future<void> _addPhoto(
    Future<String?> Function() pick,
    PhotoProblem problem,
  ) async {
    // The plugin rejects a second request while one is open, which a quick
    // double tap would otherwise cause.
    if (state.isPickingPhoto || !state.canAddPhoto) return;

    emit(state.copyWith(isPickingPhoto: true));
    try {
      final path = await pick();
      if (isClosed) return;
      emit(
        path == null
            // The user cancelled, which changes nothing.
            ? state.copyWith(isPickingPhoto: false)
            : state.copyWith(
                photos: [...state.photos, PickedPhoto(path)],
                isPickingPhoto: false,
                photoProblem: () => null,
              ),
      );
    } on PhotoUnavailable {
      if (isClosed) return;
      emit(state.copyWith(isPickingPhoto: false, photoProblem: () => problem));
    }
  }

  void removePhoto(CheckInPhoto photo) {
    emit(
      state.copyWith(
        photos: [
          for (final candidate in state.photos)
            if (candidate != photo) candidate,
        ],
      ),
    );
    // A stored photo is deleted when the edit is saved. A picked one was
    // never stored, so it can go now.
    if (photo case PickedPhoto(:final sourcePath)) {
      unawaited(_photoPicker.discard(sourcePath));
    }
  }

  Future<void> openSettings() => _photoPicker.openSettings();

  /// Choosing a type other than Other drops any activity chosen for Other.
  void selectWorkoutType(WorkoutType workoutType) {
    emit(
      state.copyWith(
        workoutType: workoutType,
        activity: () => CheckIn.activityFor(workoutType, state.activity),
      ),
    );
  }

  /// Chooses what an Other workout was, or clears it if [activity] is
  /// already chosen. Does nothing for the other types.
  void toggleActivity(OtherActivity activity) {
    if (state.workoutType != WorkoutType.other) return;
    emit(
      state.copyWith(
        activity: () => state.activity == activity ? null : activity,
      ),
    );
  }

  void noteChanged(String note) => emit(state.copyWith(note: note));

  /// Saves the check-in. On failure the form keeps its values, so the user
  /// can simply try again.
  Future<void> save() async {
    final workoutType = state.workoutType;
    if (!state.canSave || workoutType == null) return;

    emit(state.copyWith(status: CheckInStatus.saving));
    try {
      final original = state.original;
      if (original == null) {
        await _saveCheckIn(
          sourcePhotoPaths: [
            for (final photo in state.photos)
              if (photo case PickedPhoto(:final sourcePath)) sourcePath,
          ],
          workoutType: workoutType,
          activity: state.activity,
          note: state.note,
        );
      } else {
        await _updateCheckIn(
          id: original.id,
          photos: state.photos,
          workoutType: workoutType,
          activity: state.activity,
          note: state.note,
          // The form can't change these yet, so an edit keeps them.
          effort: original.effort,
          energy: original.energy,
        );
      }
      if (isClosed) return;
      emit(state.copyWith(status: CheckInStatus.saved));
    } on Failure {
      if (isClosed) return;
      emit(state.copyWith(status: CheckInStatus.failure));
    }
  }

  /// Discards the photos picked for this form.
  ///
  /// By the time the form closes, each one has either been stored, which
  /// made a copy of its own, or abandoned with the form.
  @override
  Future<void> close() async {
    for (final photo in state.photos) {
      if (photo case PickedPhoto(:final sourcePath)) {
        await _photoPicker.discard(sourcePath);
      }
    }
    return super.close();
  }
}
