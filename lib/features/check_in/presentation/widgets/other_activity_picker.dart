import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/other_activity.dart';
import '../../domain/entities/workout_type.dart';
import '../workout_type_labels.dart';
import 'pill_button.dart';

/// Says what an Other workout was, which then names the check-in.
///
/// Shown only while [workoutType] is Other. Tapping the chosen activity
/// again clears it.
class OtherActivityPicker extends StatelessWidget {
  const OtherActivityPicker({
    required this.workoutType,
    required this.selected,
    required this.onToggled,
    super.key,
  });

  final WorkoutType? workoutType;

  /// Null until the user chooses.
  final OtherActivity? selected;

  final ValueChanged<OtherActivity> onToggled;

  void _toggle(OtherActivity activity) {
    unawaited(HapticFeedback.selectionClick());
    onToggled(activity);
  }

  @override
  Widget build(BuildContext context) {
    final duration = context.motionDuration;

    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        child: workoutType != WorkoutType.other
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: const ValueKey(WorkoutType.other),
                // Less than the usual gap: each pill's tap area adds to it.
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final activity in OtherActivity.values)
                        PillButton(
                          label: activity.label,
                          isSelected: activity == selected,
                          onTap: () => _toggle(activity),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
