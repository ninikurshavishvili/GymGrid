import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/rating.dart';
import '../rating_labels.dart';
import 'pill_button.dart';

/// Rates one thing about a check-in, such as its effort, from 20% to 100%.
///
/// Optional, like the rest of the form after the workout type: tapping the
/// chosen step again clears it. Five pills rather than a slider, because a
/// slider always has a value, and here "not rated" has to be a choice too.
class RatingPicker extends StatelessWidget {
  const RatingPicker({
    required this.title,
    required this.selected,
    required this.onToggled,
    super.key,
  });

  /// What's being rated, such as "Effort". Also starts each pill's
  /// VoiceOver label, so a pill makes sense on its own.
  final String title;

  /// Null until the user chooses.
  final Rating? selected;

  final ValueChanged<Rating> onToggled;

  void _toggle(Rating rating) {
    unawaited(HapticFeedback.selectionClick());
    onToggled(rating);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A heading, so VoiceOver's rotor can jump between the two ratings.
        Semantics(
          // Its own node, so it can't merge into one around the form.
          container: true,
          header: true,
          child: Text(
            title,
            style: context.textStyles.footnote.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        // Pills keep their own widths and wrap at large text sizes, where
        // five wouldn't fit on one line. There, each pill is taller than
        // its tap area, so wrapped lines need a gap of their own.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final rating in Rating.values)
              PillButton(
                label: rating.label,
                semanticLabel: '$title ${rating.label}',
                isSelected: rating == selected,
                onTap: () => _toggle(rating),
              ),
          ],
        ),
      ],
    );
  }
}
