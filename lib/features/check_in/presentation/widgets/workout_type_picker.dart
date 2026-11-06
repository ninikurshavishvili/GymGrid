import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/workout_type.dart';
import '../workout_type_labels.dart';

/// Chooses a [WorkoutType] from a grid of tiles.
///
/// Two columns, or one at accessibility text sizes, where two would break
/// words like "Strength" in half.
class WorkoutTypePicker extends StatelessWidget {
  const WorkoutTypePicker({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Null until the user chooses.
  final WorkoutType? selected;

  final ValueChanged<WorkoutType> onSelected;

  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    const types = WorkoutType.values;
    final columns = context.usesAccessibilityTextSize ? 1 : 2;

    return Column(
      spacing: _gap,
      children: [
        for (var start = 0; start < types.length; start += columns)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _gap,
              children: [
                for (final type in types.skip(start).take(columns))
                  Expanded(
                    child: _WorkoutTile(
                      type: type,
                      isSelected: type == selected,
                      onTap: () => onSelected(type),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WorkoutTile extends StatefulWidget {
  const _WorkoutTile({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final WorkoutType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_WorkoutTile> createState() => _WorkoutTileState();
}

class _WorkoutTileState extends State<_WorkoutTile> {
  /// Whether a finger is on the tile, which presses it in slightly, like a
  /// `ButtonStyle` scale effect in SwiftUI.
  bool _isPressed = false;

  void _setPressed(bool isPressed) => setState(() => _isPressed = isPressed);

  void _select() {
    unawaited(HapticFeedback.selectionClick());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSelected = widget.isSelected;
    final type = widget.type;
    final foreground = isSelected ? colors.onAction : colors.textBody;
    final duration = context.motionDuration;

    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      label: type.label,
      // Excluding the children also drops their tap action, so the node
      // declares it again, to stay usable with VoiceOver.
      onTap: _select,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1,
        duration: duration,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isSelected ? colors.actionGreen : colors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: _select,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Icon(
                    type.icon,
                    size: MediaQuery.textScalerOf(context).scale(22),
                    color: foreground,
                  ),
                  Expanded(
                    child: Text(
                      type.label,
                      style: context.textStyles.bodyStrong.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
