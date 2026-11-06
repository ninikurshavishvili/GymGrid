import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoButton,
        CupertinoDialogAction,
        CupertinoIcons,
        CupertinoNavigationBar,
        showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/photo_frame.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/entities/check_in.dart';
import '../domain/entities/workout_type.dart';
import 'check_in_cubit.dart';
import 'check_in_state.dart';
import 'workout_type_labels.dart';

/// Today's check-in: a photo, a workout type and an optional note.
///
/// Shown as a modal with Cancel at the top and the one action pinned at the
/// bottom, which stays above the keyboard. The home screen updates by itself
/// after a save, through the database stream, so this only has to close.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

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

  void _onSaved(BuildContext context, CheckInState state) {
    unawaited(HapticFeedback.mediumImpact());
    context.pop();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Discard this check-in?'),
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
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == CheckInStatus.saved,
      listener: _onSaved,
      builder: (context, state) {
        // PopScope is Flutter's `isModalInPresentation`: it holds a leave
        // attempt back so the screen can ask first.
        return PopScope(
          canPop: !state.hasDraft,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !state.isSaving) unawaited(_confirmDiscard());
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
              middle: const Text('Check in'),
              backgroundColor: context.colors.bgPrimary,
              border: null,
              transitionBetweenRoutes: false,
            ),
            body: Column(
              children: [
                Expanded(
                  child: _Form(state: state, noteController: _noteController),
                ),
                _SaveBar(state: state),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.state, required this.noteController});

  final CheckInState state;
  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CheckInCubit>();
    final colors = context.colors;
    final text = context.textStyles;
    final photoPath = state.photoPath;
    final photoProblem = state.photoProblem;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Stack(
          children: [
            PhotoFrame(
              image: photoPath == null ? null : FileImage(File(photoPath)),
              semanticLabel: "Today's check-in photo",
              emptyLabel: "Tap to take today's photo",
              onTapEmpty: cubit.takePhoto,
              action: photoPath == null
                  ? null
                  : PhotoFrameAction(
                      icon: CupertinoIcons.camera,
                      label: 'Retake',
                      onPressed: cubit.takePhoto,
                    ),
            ),
            if (state.isPickingPhoto)
              const Positioned.fill(child: _PhotoLoading()),
          ],
        ),
        // Always here rather than only after the camera fails: the plugin
        // reports no failure on a device without a camera, and a photo taken
        // earlier at the gym is a fair check-in too.
        Center(
          child: TextButton(
            onPressed: cubit.pickFromLibrary,
            child: const Text('Choose from library'),
          ),
        ),
        if (photoProblem != null) _PhotoProblemMessage(problem: photoProblem),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Workout type',
          style: text.footnote.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        ChipSelector<WorkoutType>(
          options: WorkoutType.values,
          selected: state.workoutType,
          labelOf: (workoutType) => workoutType.label,
          onSelected: cubit.selectWorkoutType,
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: noteController,
          onChanged: cubit.noteChanged,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          maxLength: CheckIn.maxNoteLength,
          minLines: 3,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Note (optional)'),
        ),
        if (state.isReplacingToday)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              "This replaces today's check-in.",
              textAlign: TextAlign.center,
              style: text.footnote.copyWith(color: colors.textSecondary),
            ),
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

class _PhotoProblemMessage extends StatelessWidget {
  const _PhotoProblemMessage({required this.problem});

  final PhotoProblem problem;

  @override
  Widget build(BuildContext context) {
    final message = switch (problem) {
      PhotoProblem.cameraUnavailable =>
        'Camera access is off. Enable it in Settings, or choose a photo from '
            'your library.',
      PhotoProblem.libraryUnavailable =>
        "That photo couldn't be opened. Try another one.",
    };

    return Column(
      children: [
        // A live region, so VoiceOver reads this out when it appears.
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: context.textStyles.footnote.copyWith(
              color: context.colors.warning,
            ),
          ),
        ),
        if (problem == PhotoProblem.cameraUnavailable)
          TextButton(
            onPressed: context.read<CheckInCubit>().openSettings,
            child: const Text('Open Settings'),
          ),
      ],
    );
  }
}

/// The pinned Save button, with room above it for an error it can't lose to
/// scrolling.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.state});

  final CheckInState state;

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
              label: 'Save',
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
