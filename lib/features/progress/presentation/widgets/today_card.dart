import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../check_in/domain/entities/check_in.dart';
import '../../../check_in/domain/repositories/photo_locator.dart';
import '../../../check_in/presentation/check_in_display.dart';
import '../../../check_in/presentation/workout_type_labels.dart';
import '../../domain/entities/progress.dart';
import 'check_in_summary.dart';

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
    final time = checkIn.timeLabel(context);

    return SurfaceCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: [
        'Today: ${checkIn.title}',
        'checked in at $time',
        ...checkIn.ratingLabels,
        ?checkIn.notePreview,
      ].join(', '),
      child: CheckInSummary(
        checkIn: checkIn,
        cover: cover,
        when: 'Checked in at $time',
        whenColor: context.colors.gridFilled,
      ),
    );
  }
}
