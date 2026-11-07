import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/workout_type.dart';
import '../workout_type_labels.dart';
import 'pill_button.dart';

/// One-tap additions to the note, chosen for [workoutType].
///
/// Changes with the workout type, and drops each suggestion once it's in the
/// note, so there's only ever something useful on offer.
class NoteSuggestions extends StatelessWidget {
  const NoteSuggestions({
    required this.workoutType,
    required this.note,
    required this.onSelected,
    super.key,
  });

  /// Null until the user chooses, which shows nothing.
  final WorkoutType? workoutType;

  final String note;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final lowercaseNote = note.toLowerCase();
    final suggestions = [
      for (final suggestion in workoutType?.noteSuggestions ?? const <String>[])
        if (!lowercaseNote.contains(suggestion.toLowerCase())) suggestion,
    ];
    final duration = context.motionDuration;

    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        child: suggestions.isEmpty
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(workoutType),
                // Less than the usual gap: each pill's tap area adds to it.
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final suggestion in suggestions)
                        PillButton(
                          label: suggestion,
                          semanticLabel: 'Add $suggestion to the note',
                          onTap: () => onSelected(suggestion),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
