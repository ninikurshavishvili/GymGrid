import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'dashed_border_painter.dart';

/// The design's basic surface: a rounded, outlined panel on [AppColors.bgSecondary].
///
/// Pass [onTap] to make the whole card a button; [semanticLabel] then
/// describes it to screen readers. Use [BorderedCard.dashed] for empty and
/// placeholder states.
class BorderedCard extends StatelessWidget {
  const BorderedCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.semanticLabel,
  }) : _dashed = false;

  const BorderedCard.dashed({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.semanticLabel,
  }) : _dashed = true;

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Defaults to [AppColors.borderDefault].
  final Color? borderColor;

  /// Defaults to [AppColors.bgSecondary], or half of it for dashed cards.
  final Color? backgroundColor;

  final VoidCallback? onTap;
  final String? semanticLabel;

  final bool _dashed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = borderColor ?? colors.borderDefault;
    final radius = BorderRadius.circular(AppRadius.lg);

    // Material + InkWell gives the tap ripple clipped to the card's shape,
    // the Flutter counterpart of a highlighted UIControl state.
    Widget card = Material(
      color:
          backgroundColor ??
          (_dashed
              ? colors.bgSecondary.withValues(alpha: 0.5)
              : colors.bgSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: _dashed ? BorderSide.none : BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (_dashed) {
      card = CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: border,
          radius: AppRadius.lg,
        ),
        child: card,
      );
    }

    if (onTap == null && semanticLabel == null) return card;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      // Excluding the children also drops the InkWell's tap action, so the
      // node re-declares it to stay activatable with VoiceOver and TalkBack.
      onTap: onTap,
      // The label replaces the children's text so a screen reader announces
      // the card once, as a single control.
      excludeSemantics: semanticLabel != null,
      child: card,
    );
  }
}
