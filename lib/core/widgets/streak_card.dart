import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'bordered_card.dart';

/// A labelled day count, such as "Current streak: 14 days".
///
/// When [isAtRisk] is true the card switches to the warning colour and its
/// visible label reads "At risk". Screen readers still hear [label] followed
/// by ", at risk".
class StreakCard extends StatelessWidget {
  const StreakCard({
    required this.label,
    required this.days,
    super.key,
    this.icon,
    this.isAtRisk = false,
  });

  /// Plain-case label, e.g. "Current streak". Shown uppercased.
  final String label;

  final int days;

  /// Optional glyph shown before the label.
  final IconData? icon;

  final bool isAtRisk;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textStyles;

    final accent = isAtRisk ? colors.warning : null;
    final unit = days == 1 ? 'day' : 'days';
    final visibleLabel = isAtRisk ? 'At risk' : label;
    final semantics = '$label: $days $unit${isAtRisk ? ', at risk' : ''}';
    // The status dot sits beside the label rather than inside it, so it is
    // scaled by hand to grow with the text, like an SF Symbol would.
    final scaler = MediaQuery.textScalerOf(context);

    return BorderedCard(
      borderColor: accent?.withValues(alpha: 0.4),
      semanticLabel: semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // The icon is inline rather than a separate column so the
                // label keeps the card's full width and long words don't
                // break mid-word at large text sizes.
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (icon != null)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: AppSpacing.xs,
                            ),
                            // Inline widgets are scaled along with the
                            // text, so the base size is given unscaled.
                            child: Icon(
                              icon,
                              size: 12,
                              color: accent ?? colors.gridFilled,
                            ),
                          ),
                        ),
                      TextSpan(text: visibleLabel.toUpperCase()),
                    ],
                  ),
                  style: text.badge.copyWith(
                    color: accent ?? colors.textSecondary,
                  ),
                ),
              ),
              if (isAtRisk)
                Container(
                  width: scaler.scale(8),
                  height: scaler.scale(8),
                  margin: const EdgeInsetsDirectional.only(
                    start: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$days ',
                  style: text.stat.copyWith(
                    // A zero count is de-emphasised, as on a fresh install.
                    color: days == 0
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: text.monoBody.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
