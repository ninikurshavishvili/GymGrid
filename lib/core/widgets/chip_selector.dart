import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// A single-choice grid of equal-width chips, like a segmented control.
///
/// Generic over the option type so `core` stays independent of feature
/// code: the check-in feature wraps this as `WorkoutChipSelector` over its
/// `WorkoutType` enum.
///
/// All chips share one row when their labels fit. On narrow screens or with
/// large accessibility text it falls back to two columns, then one, so the
/// grid stays even and labels are never truncated.
class ChipSelector<T> extends StatelessWidget {
  const ChipSelector({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    super.key,
  });

  final List<T> options;

  /// The selected option, or null when nothing is chosen yet.
  final T? selected;

  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  static const double _gap = AppSpacing.sm - 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(context, constraints.maxWidth);

        return Column(
          spacing: _gap,
          children: [
            for (var start = 0; start < options.length; start += columns)
              Row(
                spacing: _gap,
                children: [
                  for (var i = start; i < start + columns; i++)
                    Expanded(
                      // Filler keeps chips equal width in a partial last row.
                      child: i < options.length
                          ? _Chip(
                              label: labelOf(options[i]),
                              isSelected: options[i] == selected,
                              onTap: () => onSelected(options[i]),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// The most columns (all, then 2, then 1) in which every label fits on
  /// one line at the current text scale.
  int _columnCount(BuildContext context, double maxWidth) {
    final style = _Chip.labelStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    var widestLabel = 0.0;
    for (final option in options) {
      final painter = TextPainter(
        text: TextSpan(text: labelOf(option), style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      widestLabel = math.max(widestLabel, painter.width);
      painter.dispose();
    }
    final chipWidth = widestLabel + _Chip.horizontalChrome;

    for (final columns in {options.length, 2, 1}) {
      if (columns > options.length) continue;
      if (columns * chipWidth + (columns - 1) * _gap <= maxWidth) {
        return columns;
      }
    }
    return 1;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  static const double _horizontalPadding = AppSpacing.md;
  static const double _borderWidth = 1;

  /// Width a chip adds around its label.
  static const double horizontalChrome =
      2 * (_horizontalPadding + _borderWidth);

  static TextStyle labelStyle(BuildContext context) =>
      context.textStyles.bodyStrong;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: isSelected ? colors.actionGreen : colors.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: isSelected ? colors.actionGreenBorder : colors.borderDefault,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // 9 + 16 line height + 9 matches the design's chip height while
            // still growing with the text size.
            padding: const EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: AppSpacing.sm + 1,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: labelStyle(context).copyWith(
                color: isSelected ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
