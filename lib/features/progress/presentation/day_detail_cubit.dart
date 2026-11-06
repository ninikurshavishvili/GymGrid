import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/date/calendar_day.dart';
import '../../../core/errors/failure.dart';
import '../../check_in/domain/entities/check_in.dart';
import '../../check_in/domain/entities/check_in_photo.dart';
import '../../check_in/domain/usecases/delete_check_in.dart';
import '../../check_in/domain/usecases/update_check_in.dart';
import '../../check_in/domain/usecases/watch_check_in.dart';
import '../../check_in/presentation/photo_picker.dart';
import 'day_detail_state.dart';

/// Shows one day's check-in, kept current as it changes, and lets the user
/// add a photo to it or delete it.
class DayDetailCubit extends Cubit<DayDetailState> {
  DayDetailCubit({
    required CalendarDay day,
    required WatchCheckIn watchCheckIn,
    required UpdateCheckIn updateCheckIn,
    required DeleteCheckIn deleteCheckIn,
    required PhotoPicker photoPicker,
  }) : _day = day,
       _watchCheckIn = watchCheckIn,
       _updateCheckIn = updateCheckIn,
       _deleteCheckIn = deleteCheckIn,
       _photoPicker = photoPicker,
       super(const DayDetailLoading());

  final CalendarDay _day;
  final WatchCheckIn _watchCheckIn;
  final UpdateCheckIn _updateCheckIn;
  final DeleteCheckIn _deleteCheckIn;
  final PhotoPicker _photoPicker;

  StreamSubscription<CheckIn?>? _subscription;

  /// Starts following the day's check-in, replacing any earlier
  /// subscription. Also what "Try again" calls after a failure.
  void watch() {
    if (state is! DayDetailLoading) emit(const DayDetailLoading());
    _subscribe();
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _watchCheckIn(_day).listen(_onCheckIn, onError: _onError);
  }

  void _onCheckIn(CheckIn? checkIn) {
    if (checkIn == null) {
      emit(const DayDetailNotFound());
      return;
    }

    final current = state;
    emit(
      current is DayDetailLoaded
          // Keeps any action in progress, which this change may come from.
          ? current.copyWith(checkIn: checkIn)
          : DayDetailLoaded(checkIn),
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    // The repository reports every storage error as a Failure, so anything
    // else is a bug and should surface as one, not as a "Try again" screen.
    if (error is! Failure) Error.throwWithStackTrace(error, stackTrace);
    emit(DayDetailFailure(error));
  }

  Future<void> takePhoto() =>
      _addPhoto(_photoPicker.takePhoto, PhotoProblem.cameraUnavailable);

  Future<void> pickFromLibrary() =>
      _addPhoto(_photoPicker.pickFromLibrary, PhotoProblem.libraryUnavailable);

  Future<void> _addPhoto(
    Future<String?> Function() pick,
    PhotoProblem problem,
  ) async {
    final current = state;
    if (current is! DayDetailLoaded || current.isBusy || !current.canAddPhoto) {
      return;
    }

    emit(
      current.copyWith(
        activity: DayDetailActivity.addingPhoto,
        photoProblem: () => null,
        error: () => null,
      ),
    );

    try {
      final path = await pick();
      if (isClosed) return;
      if (path != null) {
        final checkIn = current.checkIn;
        await _updateCheckIn(
          id: checkIn.id,
          photos: [
            for (final photoPath in checkIn.photoPaths) StoredPhoto(photoPath),
            PickedPhoto(path),
          ],
          workoutType: checkIn.workoutType,
          note: checkIn.note,
        );
      }
      _finishAddingPhoto();
    } on PhotoUnavailable {
      _finishAddingPhoto(photoProblem: problem);
    } on Failure {
      _finishAddingPhoto(error: DayDetailError.photoNotSaved);
    }
  }

  void _finishAddingPhoto({PhotoProblem? photoProblem, DayDetailError? error}) {
    final current = state;
    if (isClosed || current is! DayDetailLoaded) return;

    emit(
      current.copyWith(
        activity: DayDetailActivity.idle,
        photoProblem: () => photoProblem,
        error: () => error,
      ),
    );
  }

  Future<void> openSettings() => _photoPicker.openSettings();

  /// Deletes the check-in. The screen closes on [DayDetailDeleted].
  Future<void> delete() async {
    final current = state;
    if (current is! DayDetailLoaded || current.isBusy) return;

    // Stops watching first, or the deletion could arrive as "there's no
    // check-in on this day" and flash that message on the way out.
    unawaited(_subscription?.cancel());
    emit(
      current.copyWith(
        activity: DayDetailActivity.deleting,
        photoProblem: () => null,
        error: () => null,
      ),
    );

    try {
      await _deleteCheckIn(current.checkIn.id);
      if (isClosed) return;
      emit(const DayDetailDeleted());
    } on Failure {
      if (isClosed) return;
      emit(
        current.copyWith(
          activity: DayDetailActivity.idle,
          error: () => DayDetailError.notDeleted,
        ),
      );
      _subscribe();
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
