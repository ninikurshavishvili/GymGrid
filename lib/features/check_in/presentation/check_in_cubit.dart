import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/date/calendar_day.dart';
import '../../../core/errors/failure.dart';
import '../domain/entities/check_in_photo.dart';
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
  }

  Future<void> openSettings() => _photoPicker.openSettings();

  void selectWorkoutType(WorkoutType workoutType) {
    emit(state.copyWith(workoutType: workoutType));
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
          note: state.note,
        );
      } else {
        await _updateCheckIn(
          id: original.id,
          photos: state.photos,
          workoutType: workoutType,
          note: state.note,
        );
      }
      if (isClosed) return;
      emit(state.copyWith(status: CheckInStatus.saved));
    } on Failure {
      if (isClosed) return;
      emit(state.copyWith(status: CheckInStatus.failure));
    }
  }
}
