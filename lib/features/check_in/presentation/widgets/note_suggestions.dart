import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/workout_type.dart';
import '../workout_type_labels.dart';

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
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final suggestion in suggestions)
                        _SuggestionPill(
                          label: suggestion,
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

class _SuggestionPill extends StatelessWidget {
  const _SuggestionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add $label to the note',
      // Excluding the children also drops their tap action, so the node
      // declares it again, to stay usable with VoiceOver.
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: context.colors.bgSecondary,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: context.textStyles.footnote.copyWith(
                color: context.colors.textBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
