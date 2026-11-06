import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../check_in/domain/entities/check_in.dart';
import '../../../check_in/domain/repositories/photo_locator.dart';
import '../../../check_in/presentation/check_in_display.dart';
import '../../../check_in/presentation/workout_type_labels.dart';
import '../../domain/entities/progress.dart';

/// Today's status: the check-in as a row that opens it, or a reminder.
class TodayCard extends StatelessWidget {
  const TodayCard({
    required this.progress,
    required this.photoLocator,
    required this.onOpen,
    super.key,
  });

  final Progress progress;
  final PhotoLocator photoLocator;

  /// Called when the user opens today's check-in.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (progress.todaysCheckIn case final checkIn?) {
      return _CheckedIn(
        checkIn: checkIn,
        cover: photoLocator.imageOf(checkIn.coverPhotoPath),
        onOpen: onOpen,
      );
    }
    return _NotCheckedIn(progress: progress);
  }
}

class _NotCheckedIn extends StatelessWidget {
  const _NotCheckedIn({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;
    final streaks = progress.streaks;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xxs,
        children: [
          Text(
            'Today',
            style: text.bodyStrong.copyWith(color: colors.textPrimary),
          ),
          Text(
            streaks.isAtRisk
                ? 'Check in to keep your ${streaks.current}-day streak'
                : 'No check-in yet',
            style: text.footnote.copyWith(
              color: streaks.isAtRisk ? colors.warning : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckedIn extends StatelessWidget {
  const _CheckedIn({
    required this.checkIn,
    required this.cover,
    required this.onOpen,
  });

  final CheckIn checkIn;
  final ImageProvider cover;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;

    final time = checkIn.timeLabel(context);
    final workout = checkIn.workoutType.label;
    final note = checkIn.note?.split('\n').first;

    final thumbnail = _Thumbnail(image: cover);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xxs,
      children: [
        Text(
          workout,
          style: text.bodyStrong.copyWith(color: colors.textPrimary),
        ),
        Text(
          'Checked in at $time',
          style: text.footnote.copyWith(color: colors.gridFilled),
        ),
        if (note != null)
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.footnote.copyWith(color: colors.textSecondary),
          ),
      ],
    );
    // The iOS disclosure indicator: this row opens a detail screen.
    final disclosure = Icon(
      CupertinoIcons.chevron_forward,
      size: MediaQuery.textScalerOf(context).scale(14),
      color: colors.textMuted,
    );

    return SurfaceCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: [
        'Today: $workout',
        'checked in at $time',
        ?note,
      ].join(', '),
      // At accessibility sizes the photo moves above the text, as iOS rows
      // do, so a word like "Strength" keeps a whole line to itself.
      child: context.usesAccessibilityTextSize
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [thumbnail, disclosure],
                ),
                details,
              ],
            )
          : Row(
              spacing: AppSpacing.md,
              children: [
                thumbnail,
                Expanded(child: details),
                disclosure,
              ],
            ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.image});

  final ImageProvider image;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox.square(
        dimension: _size,
        // The fill also shows for the moment the photo takes to decode.
        child: ColoredBox(
          color: context.colors.bgTertiary,
          child: Image(
            // Decoded at the size it's shown, not at camera resolution.
            image: ResizeImage.resizeIfNeeded(
              (_size * MediaQuery.devicePixelRatioOf(context)).round(),
              null,
              image,
            ),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Icon(
                CupertinoIcons.photo,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
