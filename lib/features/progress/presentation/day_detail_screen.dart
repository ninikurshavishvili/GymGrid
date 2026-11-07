import 'dart:async';

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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/date/calendar_day.dart';
import '../../../core/widgets/navigation_back_button.dart';
import '../../../core/widgets/surface_card.dart';
import '../../check_in/domain/entities/check_in.dart';
import '../../check_in/domain/entities/rating.dart';
import '../../check_in/domain/repositories/photo_locator.dart';
import '../../check_in/presentation/check_in_display.dart';
import '../../check_in/presentation/rating_labels.dart';
import '../../check_in/presentation/widgets/photo_problem_message.dart';
import '../../check_in/presentation/widgets/photo_source_sheet.dart';
import '../../check_in/presentation/workout_type_labels.dart';
import 'day_detail_cubit.dart';
import 'day_detail_state.dart';
import 'widgets/photo_pager.dart';

/// One day's check-in: its photos, workout, note and ratings, with what can
/// be done to it. Stays current by itself when the check-in is edited.
class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({
    required this.day,
    required this.photoLocator,
    super.key,
  });

  final CalendarDay day;
  final PhotoLocator photoLocator;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(day.toLocalDateTime());

    return BlocConsumer<DayDetailCubit, DayDetailState>(
      listenWhen: (previous, current) => current is DayDetailDeleted,
      listener: (context, state) => context.pop(),
      builder: (context, state) {
        return Scaffold(
          appBar: CupertinoNavigationBar(
            automaticallyImplyLeading: false,
            leading: const NavigationBackButton(),
            middle: Text(date),
            trailing: state is DayDetailLoaded && !state.isBusy
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        unawaited(context.push(AppRoutes.editDay(day))),
                    child: const Text('Edit'),
                  )
                : null,
            backgroundColor: context.colors.bgPrimary,
            border: null,
            transitionBetweenRoutes: false,
          ),
          body: switch (state) {
            DayDetailLoaded() => _Content(
              state: state,
              photoLocator: photoLocator,
            ),
            DayDetailNotFound() => const _Message(
              text: 'No check-in on this day',
            ),
            DayDetailFailure() => const _Message(
              text: "Couldn't load this check-in",
              canRetry: true,
            ),
            // Nothing new to show: the screen is on its way out.
            DayDetailLoading() || DayDetailDeleted() => const Center(
              child: CupertinoActivityIndicator(),
            ),
          },
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.photoLocator});

  final DayDetailLoaded state;
  final PhotoLocator photoLocator;

  Future<void> _addPhoto(BuildContext context) async {
    final cubit = context.read<DayDetailCubit>();
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

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<DayDetailCubit>();
    final photos = state.checkIn.photoPaths.length == 1
        ? 'Its photo'
        : 'Its photos';

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete this check-in?'),
        content: Text('$photos will be removed from GymGrid.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await cubit.delete();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DayDetailCubit>();
    final colors = context.colors;
    final text = context.textStyles;
    final checkIn = state.checkIn;
    final note = checkIn.note;
    final photoProblem = state.photoProblem;
    final error = switch (state.error) {
      DayDetailError.photoNotSaved => "Couldn't add your photo. Try again.",
      DayDetailError.notDeleted => "Couldn't delete this check-in. Try again.",
      null => null,
    };

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PhotoPager(
            images: [
              for (final path in checkIn.photoPaths) photoLocator.imageOf(path),
            ],
            caption: checkIn.timeLabel(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Icon(
                checkIn.titleIcon,
                size: MediaQuery.textScalerOf(context).scale(20),
                color: colors.gridFilled,
              ),
              Expanded(
                child: Text(
                  checkIn.title,
                  style: text.header.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(note, style: text.body.copyWith(color: colors.textBody)),
          ],
          if (checkIn.ratingLabels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Ratings(checkIn: checkIn),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (photoProblem != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PhotoProblemMessage(
                problem: photoProblem,
                onOpenSettings: cubit.openSettings,
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: text.footnote.copyWith(color: colors.dangerRed),
                ),
              ),
            ),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (state.canAddPhoto) ...[
                  _ActionRow(
                    icon: CupertinoIcons.plus,
                    label: 'Add photo',
                    color: colors.actionGreen,
                    isLoading: state.activity == DayDetailActivity.addingPhoto,
                    onTap: state.isBusy
                        ? null
                        : () => unawaited(_addPhoto(context)),
                  ),
                  const Divider(indent: AppSpacing.lg),
                ],
                _ActionRow(
                  icon: CupertinoIcons.trash,
                  label: 'Delete check-in',
                  color: colors.dangerRed,
                  isLoading: state.activity == DayDetailActivity.deleting,
                  onTap: state.isBusy
                      ? null
                      : () => unawaited(_confirmDelete(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of a grouped list that performs an action.
/// The effort and energy the user rated, side by side, like the streak
/// cards on home. A rating left out doesn't appear.
class _Ratings extends StatelessWidget {
  const _Ratings({required this.checkIn});

  final CheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;
    final ratings = <(String, Rating)>[
      if (checkIn.effort case final effort?) ('Effort', effort),
      if (checkIn.energy case final energy?) ('Energy', energy),
    ];
    final values = [
      for (final (name, rating) in ratings)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xxs,
          children: [
            Text(
              name,
              style: text.footnote.copyWith(color: colors.textSecondary),
            ),
            Text(
              rating.label,
              style: text.header.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
    ];

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      // Read once, as "Effort 80%, Energy 40%".
      semanticLabel: checkIn.ratingLabels.join(', '),
      // Stacked at accessibility sizes, where "100%" needs the full width.
      child: context.usesAccessibilityTextSize
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: values,
            )
          : Row(
              spacing: AppSpacing.lg,
              children: [for (final value in values) Expanded(child: value)],
            ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconSize = MediaQuery.textScalerOf(context).scale(18);

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      // Excluding the children also drops their tap action, so the node
      // declares it again, to stay usable with VoiceOver.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            spacing: AppSpacing.md,
            children: [
              if (isLoading)
                SizedBox.square(
                  dimension: iconSize,
                  child: const CupertinoActivityIndicator(),
                )
              else
                Icon(icon, size: iconSize, color: color),
              Expanded(
                child: Text(
                  label,
                  style: context.textStyles.body.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.canRetry = false});

  final String text;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyStrong.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            if (canRetry)
              TextButton(
                onPressed: context.read<DayDetailCubit>().watch,
                child: const Text('Try again'),
              ),
          ],
        ),
      ),
    );
  }
}
