import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Colour treatments for [PrimaryButton].
enum PrimaryButtonTone { action, danger }

/// The full-width call-to-action button.
///
/// Disabled when [onPressed] is null. While [isLoading] is true the button
/// ignores taps and shows a spinner in place of [icon]; the label stays so
/// the button keeps its size and its screen-reader name.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.tone = PrimaryButtonTone.action,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final PrimaryButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (tone) {
      PrimaryButtonTone.action => (colors.actionGreen, colors.onAction),
      PrimaryButtonTone.danger => (colors.dangerRed, colors.textPrimary),
    };
    final enabled = onPressed != null && !isLoading;
    // The icon grows with the label, like an SF Symbol in a UIButton.
    final iconSize = MediaQuery.textScalerOf(context).scale(17);

    final Widget? leading = isLoading
        ? CupertinoActivityIndicator(radius: iconSize / 2, color: foreground)
        : icon == null
        ? null
        : Icon(icon, size: iconSize);

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        // Loading disables taps but keeps the enabled colours; a plain
        // disabled button falls back to the theme's grey.
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: isLoading ? background : null,
          disabledForegroundColor: isLoading ? foreground : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: AppSpacing.sm),
            ],
            // Flexible lets a long label wrap under large text sizes instead
            // of overflowing the button.
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
