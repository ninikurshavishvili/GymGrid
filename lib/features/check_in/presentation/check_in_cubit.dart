import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/date/clock.dart';
import '../../../core/errors/failure.dart';
import '../domain/entities/workout_type.dart';
import '../domain/usecases/get_check_in.dart';
import '../domain/usecases/save_check_in.dart';
import 'check_in_state.dart';
import 'photo_picker.dart';

/// Runs the check-in form: getting a photo, editing it, and saving.
class CheckInCubit extends Cubit<CheckInState> {
  CheckInCubit({
    required SaveCheckIn saveCheckIn,
    required GetCheckIn getCheckIn,
    required PhotoPicker photoPicker,
    required Clock clock,
  }) : _saveCheckIn = saveCheckIn,
       _getCheckIn = getCheckIn,
       _photoPicker = photoPicker,
       _clock = clock,
       super(const CheckInState());

  final SaveCheckIn _saveCheckIn;
  final GetCheckIn _getCheckIn;
  final PhotoPicker _photoPicker;
  final Clock _clock;

  /// Finds out whether saving would replace today's check-in.
  Future<void> load() async {
    try {
      final existing = await _getCheckIn(_clock.today());
      if (isClosed) return;
      emit(state.copyWith(isReplacingToday: existing != null));
    } on Failure {
      // This only decides whether to show a note. If storage really is
      // failing, saving will report it.
    }
  }

  Future<void> takePhoto() =>
      _pickPhoto(_photoPicker.takePhoto, PhotoProblem.cameraUnavailable);

  Future<void> pickFromLibrary() =>
      _pickPhoto(_photoPicker.pickFromLibrary, PhotoProblem.libraryUnavailable);

  Future<void> _pickPhoto(
    Future<String?> Function() pick,
    PhotoProblem problem,
  ) async {
    // The plugin rejects a second request while one is open, which a quick
    // double tap would otherwise cause.
    if (state.isPickingPhoto) return;

    emit(state.copyWith(isPickingPhoto: true));
    try {
      final path = await pick();
      if (isClosed) return;
      emit(
        path == null
            // The user cancelled, which keeps any earlier photo.
            ? state.copyWith(isPickingPhoto: false)
            : state.copyWith(
                photoPath: path,
                isPickingPhoto: false,
                photoProblem: () => null,
              ),
      );
    } on PhotoUnavailable {
      if (isClosed) return;
      emit(state.copyWith(isPickingPhoto: false, photoProblem: () => problem));
    }
  }

  Future<void> openSettings() => _photoPicker.openSettings();

  void selectWorkoutType(WorkoutType workoutType) {
    emit(state.copyWith(workoutType: workoutType));
  }

  void noteChanged(String note) => emit(state.copyWith(note: note));

  /// Saves the check-in. On failure the form keeps its values, so the user
  /// can simply try again.
  Future<void> save() async {
    final photoPath = state.photoPath;
    final workoutType = state.workoutType;
    if (photoPath == null || workoutType == null || state.isSaving) return;

    emit(state.copyWith(status: CheckInStatus.saving));
    try {
      await _saveCheckIn(
        sourcePhotoPath: photoPath,
        workoutType: workoutType,
        note: state.note,
      );
      if (isClosed) return;
      emit(state.copyWith(status: CheckInStatus.saved));
    } on Failure {
      if (isClosed) return;
      emit(state.copyWith(status: CheckInStatus.failure));
    }
  }
}
