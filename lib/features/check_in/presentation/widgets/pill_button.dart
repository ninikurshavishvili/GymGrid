import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// A small capsule with a word in it, for one-tap additions and for choices
/// from a short list.
class PillButton extends StatelessWidget {
  const PillButton({
    required this.label,
    required this.onTap,
    this.semanticLabel,
    this.isSelected,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  /// What VoiceOver reads instead of [label], when the word alone doesn't
  /// say what tapping does.
  final String? semanticLabel;

  /// Null for a plain button. True or false makes this one of a set of
  /// choices: it's filled in when chosen, and VoiceOver says whether it is.
  final bool? isSelected;

  /// Apple's minimum tap target. The pill drawn inside it is smaller.
  static const double _minTapHeight = 44;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSelected = this.isSelected ?? false;
    final duration = context.motionDuration;

    return Semantics(
      container: true,
      button: true,
      selected: this.isSelected,
      inMutuallyExclusiveGroup: this.isSelected != null,
      label: semanticLabel ?? label,
      // Excluding the children also drops their tap action, so the node
      // declares it again, to stay usable with VoiceOver.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTapHeight),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              decoration: ShapeDecoration(
                color: isSelected ? colors.actionGreen : colors.bgSecondary,
                shape: const StadiumBorder(),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                label,
                style: context.textStyles.footnote.copyWith(
                  color: isSelected ? colors.onAction : colors.textBody,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
