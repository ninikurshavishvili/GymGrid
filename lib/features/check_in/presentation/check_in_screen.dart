import 'dart:async';

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoButton,
        CupertinoDialogAction,
        CupertinoNavigationBar,
        showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/photo_frame.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/entities/check_in.dart';
import '../domain/repositories/photo_locator.dart';
import 'check_in_cubit.dart';
import 'check_in_display.dart';
import 'check_in_state.dart';
import 'widgets/note_suggestions.dart';
import 'widgets/other_activity_picker.dart';
import 'widgets/photo_problem_message.dart';
import 'widgets/photo_source_sheet.dart';
import 'widgets/photo_strip.dart';
import 'widgets/rating_picker.dart';
import 'widgets/workout_type_picker.dart';
import 'workout_type_labels.dart';

/// The check-in form: photos, a workout type, and optionally effort, energy
/// and a note, for a new check-in or an existing one.
///
/// Shown as a modal with Cancel at the top and the one action pinned at the
/// bottom, which stays above the keyboard. The form responds as it's filled
/// in: the note's prompt and suggestions follow the workout type, Other asks
/// what the workout was, and the button says what's still needed. Screens
/// showing check-ins update by themselves after a save, through the
/// database stream, so this only has to close.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({required this.photoLocator, super.key});

  final PhotoLocator photoLocator;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  // Owned here because a TextField keeps its own editing state, such as the
  // selection, and the Cubit only needs to hear the text.
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onStatusChanged(BuildContext context, CheckInState state) {
    switch (state.status) {
      case CheckInStatus.saved:
        unawaited(HapticFeedback.mediumImpact());
        context.pop();
      case CheckInStatus.editing when state.original != null:
        // The check-in being edited has just loaded.
        _noteController.text = state.note;
      case _:
        break;
    }
  }

  void _addSuggestion(String suggestion) {
    final current = _noteController.text.trimRight();
    final note = current.isEmpty ? suggestion : '$current, $suggestion';
    if (note.characters.length > CheckIn.maxNoteLength) return;

    _noteController.value = TextEditingValue(
      text: note,
      selection: TextSelection.collapsed(offset: note.length),
    );
    context.read<CheckInCubit>().noteChanged(note);
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _confirmDiscard(CheckInState state) async {
    final discard = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          state.isEditing ? 'Discard your changes?' : 'Discard this check-in?',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (mounted && (discard ?? false)) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckInCubit, CheckInState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onStatusChanged,
      builder: (context, state) {
        // PopScope is Flutter's `isModalInPresentation`: it holds a leave
        // attempt back so the screen can ask first.
        return PopScope(
          canPop: !state.hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !state.isSaving) {
              unawaited(_confirmDiscard(state));
            }
          },
          child: Scaffold(
            appBar: CupertinoNavigationBar(
              automaticallyImplyLeading: false,
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: state.isSaving
                    ? null
                    : () => unawaited(Navigator.of(context).maybePop()),
                child: const Text('Cancel'),
              ),
              middle: Text(state.isEditing ? 'Edit check-in' : 'Check in'),
              backgroundColor: context.colors.bgPrimary,
              border: null,
              transitionBetweenRoutes: false,
            ),
            body: switch (state.status) {
              CheckInStatus.loading => const Center(
                child: CupertinoActivityIndicator(),
              ),
              CheckInStatus.loadFailed => const _LoadFailedMessage(),
              _ => Column(
                children: [
                  Expanded(
                    child: _Form(
                      state: state,
                      photoLocator: widget.photoLocator,
                      noteController: _noteController,
                      onSuggestionSelected: _addSuggestion,
                    ),
                  ),
                  _SaveBar(state: state),
                ],
              ),
            },
          ),
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.photoLocator,
    required this.noteController,
    required this.onSuggestionSelected,
  });

  final CheckInState state;
  final PhotoLocator photoLocator;
  final TextEditingController noteController;
  final ValueChanged<String> onSuggestionSelected;

  Future<void> _addPhoto(BuildContext context) async {
    final cubit = context.read<CheckInCubit>();
    final source = await showPhotoSourceSheet(context);
    switch (source) {
      case PhotoSource.camera:
        await cubit.takePhoto();
      case PhotoSource.library:
        await cubit.pickFromLibrary();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CheckInCubit>();
    final colors = context.colors;
    final text = context.textStyles;
    final photoProblem = state.photoProblem;
    final duration = context.motionDuration;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AnimatedSwitcher(
          duration: duration,
          child: state.photos.isEmpty
              ? _FirstPhoto(
                  isPicking: state.isPickingPhoto,
                  onTakePhoto: cubit.takePhoto,
                  onPickFromLibrary: cubit.pickFromLibrary,
                )
              : PhotoStrip(
                  photos: state.photos,
                  imageOf: photoLocator.imageOfPhoto,
                  canAdd: state.canAddPhoto,
                  isAdding: state.isPickingPhoto,
                  onAdd: () => unawaited(_addPhoto(context)),
                  onRemove: cubit.removePhoto,
                ),
        ),
        if (photoProblem != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: PhotoProblemMessage(
              problem: photoProblem,
              onOpenSettings: cubit.openSettings,
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        WorkoutTypePicker(
          selected: state.workoutType,
          onSelected: cubit.selectWorkoutType,
        ),
        const SizedBox(height: AppSpacing.md),
        OtherActivityPicker(
          workoutType: state.workoutType,
          selected: state.activity,
          onToggled: cubit.toggleActivity,
        ),
        RatingPicker(
          title: 'Effort',
          selected: state.effort,
          onToggled: cubit.toggleEffort,
        ),
        const SizedBox(height: AppSpacing.sm),
        RatingPicker(
          title: 'Energy',
          selected: state.energy,
          onToggled: cubit.toggleEnergy,
        ),
        const SizedBox(height: AppSpacing.lg),
        NoteSuggestions(
          workoutType: state.workoutType,
          note: state.note,
          onSelected: onSuggestionSelected,
        ),
        TextField(
          controller: noteController,
          onChanged: cubit.noteChanged,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          maxLength: CheckIn.maxNoteLength,
          // The limit only matters once there's something to count.
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => currentLength == 0
              ? null
              : Text(
                  '$currentLength/$maxLength',
                  style: text.footnote.copyWith(color: colors.textSecondary),
                ),
          minLines: 2,
          maxLines: 6,
          scrollPadding: _noteScrollPadding(context, text.footnote),
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: state.workoutType?.notePrompt ?? 'Add a note (optional)',
          ),
        ),
      ],
    );
  }
}

/// How much room the note keeps around its cursor when it scrolls the form
/// to show it, as while typing with the keyboard up.
///
/// A text field only brings its cursor into view, plus 20 points. Below the
/// last line, though, are the field's own padding and the character count,
/// which then stayed hidden behind the Save bar. This adds them below the
/// cursor, measured at the current text size, like setting a scroll view's
/// content inset to clear an accessory view in UIKit.
EdgeInsets _noteScrollPadding(BuildContext context, TextStyle counterStyle) {
  // TextField's own default margin.
  const margin = AppSpacing.xl;
  // Material leaves this gap between the field and its counter.
  const counterGap = AppSpacing.xs;

  final fieldPadding =
      Theme.of(context).inputDecorationTheme.contentPadding
          ?.resolve(Directionality.of(context))
          .bottom ??
      0;
  final counter = TextPainter(
    text: TextSpan(text: '0', style: counterStyle),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
  )..layout();
  final counterHeight = counter.height;
  counter.dispose();

  return EdgeInsets.fromLTRB(
    margin,
    margin,
    margin,
    margin + fieldPadding + counterGap + counterHeight,
  );
}

/// The photo area before there's a photo: one big target for the camera.
class _FirstPhoto extends StatelessWidget {
  const _FirstPhoto({
    required this.isPicking,
    required this.onTakePhoto,
    required this.onPickFromLibrary,
  });

  final bool isPicking;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromLibrary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            PhotoFrame(
              image: null,
              semanticLabel: "Today's check-in photo",
              emptyLabel: "Tap to take today's photo",
              onTapEmpty: onTakePhoto,
            ),
            if (isPicking) const Positioned.fill(child: _PhotoLoading()),
          ],
        ),
        // Always here rather than only after the camera fails: the plugin
        // reports no failure on a device without a camera, and a photo taken
        // earlier at the gym is a fair check-in too.
        TextButton(
          onPressed: onPickFromLibrary,
          child: const Text('Choose from library'),
        ),
      ],
    );
  }
}

/// Covers the frame while a picked photo is prepared, a moment after the
/// picker closes that would otherwise look like nothing had happened.
class _PhotoLoading extends StatelessWidget {
  const _PhotoLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading photo',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.overlayScrim,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: const Center(child: CupertinoActivityIndicator()),
      ),
    );
  }
}

class _LoadFailedMessage extends StatelessWidget {
  const _LoadFailedMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          "Couldn't load this check-in",
          textAlign: TextAlign.center,
          style: context.textStyles.bodyStrong.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// The pinned button, which says what's still needed until the form can be
/// saved, with room above it for an error it can't lose to scrolling.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.state});

  final CheckInState state;

  String get _label {
    if (state.photos.isEmpty) return 'Add a photo to continue';
    if (state.workoutType == null) return 'Choose a workout';
    return state.isEditing ? 'Save changes' : 'Save check-in';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.sm,
          children: [
            if (state.status == CheckInStatus.failure)
              Semantics(
                liveRegion: true,
                child: Text(
                  "Couldn't save your check-in. Try again.",
                  textAlign: TextAlign.center,
                  style: context.textStyles.footnote.copyWith(
                    color: context.colors.dangerRed,
                  ),
                ),
              ),
            PrimaryButton(
              label: _label,
              isLoading: state.isSaving,
              onPressed: state.canSave
                  ? context.read<CheckInCubit>().save
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
