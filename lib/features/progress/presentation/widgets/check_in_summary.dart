import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../check_in/domain/entities/check_in.dart';
import '../../../check_in/presentation/check_in_display.dart';
import '../../../check_in/presentation/workout_type_labels.dart';

/// A check-in as a list row: its cover photo, title, a line saying when,
/// and the start of its note, with the iOS disclosure chevron because the
/// row opens it.
///
/// Only the contents: callers make it a button, with a label for VoiceOver
/// that fits where it's shown.
class CheckInSummary extends StatelessWidget {
  const CheckInSummary({
    required this.checkIn,
    required this.cover,
    required this.when,
    required this.whenColor,
    super.key,
  });

  final CheckIn checkIn;
  final ImageProvider cover;

  /// The line under the title, such as "Checked in at 14:19".
  final String when;

  final Color whenColor;

  /// The width and height of the cover photo.
  static const double photoSize = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;
    final note = checkIn.notePreview;

    final thumbnail = _Thumbnail(image: cover);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xxs,
      children: [
        Text(
          checkIn.title,
          style: text.bodyStrong.copyWith(color: colors.textPrimary),
        ),
        Text(when, style: text.footnote.copyWith(color: whenColor)),
        if (note != null)
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.footnote.copyWith(color: colors.textSecondary),
          ),
      ],
    );
    final disclosure = Icon(
      CupertinoIcons.chevron_forward,
      size: MediaQuery.textScalerOf(context).scale(14),
      color: colors.textMuted,
    );

    // At accessibility sizes the photo moves above the text, as iOS rows
    // do, so a word like "Strength" keeps a whole line to itself.
    if (context.usesAccessibilityTextSize) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [thumbnail, disclosure],
          ),
          details,
        ],
      );
    }
    return Row(
      spacing: AppSpacing.md,
      children: [
        thumbnail,
        Expanded(child: details),
        disclosure,
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox.square(
        dimension: CheckInSummary.photoSize,
        // The fill also shows for the moment the photo takes to decode.
        child: ColoredBox(
          color: context.colors.bgTertiary,
          child: Image(
            // Decoded at the size it's shown, not at camera resolution.
            image: ResizeImage.resizeIfNeeded(
              (CheckInSummary.photoSize *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
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
