import 'package:flutter/material.dart';

/// GymGrid's colour tokens, read in widgets through `context.colors`.
///
/// The first seven names come from the design spec. The rest cover colours
/// the design uses that the spec doesn't name, so no screen needs a raw hex.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.borderDefault,
    required this.gridEmpty,
    required this.gridFilled,
    required this.actionGreen,
    required this.actionGreenBorder,
    required this.successSubtle,
    required this.dangerRed,
    required this.warning,
    required this.accentBlue,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.textMuted,
  });

  static const AppColors dark = AppColors(
    bgPrimary: Color(0xFF0D1117),
    bgSecondary: Color(0xFF161B22),
    bgTertiary: Color(0xFF21262D),
    borderDefault: Color(0xFF30363D),
    gridEmpty: Color(0xFF21262D),
    gridFilled: Color(0xFF39D353),
    actionGreen: Color(0xFF238636),
    actionGreenBorder: Color(0xFF2EA043),
    successSubtle: Color(0xFF0E4429),
    dangerRed: Color(0xFFDA3633),
    warning: Color(0xFFE3B341),
    accentBlue: Color(0xFF58A6FF),
    textPrimary: Color(0xFFFFFFFF),
    textBody: Color(0xFFC9D1D9),
    textSecondary: Color(0xFF8B949E),
    textMuted: Color(0xFF484F58),
  );

  /// Screen background.
  final Color bgPrimary;

  /// Cards, inputs and dialogs.
  final Color bgSecondary;

  /// Secondary buttons, icon wells and hairline dividers.
  final Color bgTertiary;

  /// Card and input outlines.
  final Color borderDefault;

  /// A grid day without a check-in.
  final Color gridEmpty;

  /// A grid day with a check-in.
  final Color gridFilled;

  /// Primary buttons and the selected workout chip.
  final Color actionGreen;

  /// Outline for green elements: selected chip, focused input, pending today.
  final Color actionGreenBorder;

  /// Background behind green text, such as badges.
  final Color successSubtle;

  /// Destructive actions.
  final Color dangerRed;

  /// The "at risk" streak state.
  final Color warning;

  /// Text links such as Back.
  final Color accentBlue;

  /// Headings, numbers and button labels.
  final Color textPrimary;

  /// Long-form text such as notes.
  final Color textBody;

  /// Labels and supporting text.
  final Color textSecondary;

  /// De-emphasised text, such as labels on an empty grid.
  final Color textMuted;

  @override
  AppColors copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? bgTertiary,
    Color? borderDefault,
    Color? gridEmpty,
    Color? gridFilled,
    Color? actionGreen,
    Color? actionGreenBorder,
    Color? successSubtle,
    Color? dangerRed,
    Color? warning,
    Color? accentBlue,
    Color? textPrimary,
    Color? textBody,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return AppColors(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      bgTertiary: bgTertiary ?? this.bgTertiary,
      borderDefault: borderDefault ?? this.borderDefault,
      gridEmpty: gridEmpty ?? this.gridEmpty,
      gridFilled: gridFilled ?? this.gridFilled,
      actionGreen: actionGreen ?? this.actionGreen,
      actionGreenBorder: actionGreenBorder ?? this.actionGreenBorder,
      successSubtle: successSubtle ?? this.successSubtle,
      dangerRed: dangerRed ?? this.dangerRed,
      warning: warning ?? this.warning,
      accentBlue: accentBlue ?? this.accentBlue,
      textPrimary: textPrimary ?? this.textPrimary,
      textBody: textBody ?? this.textBody,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bgPrimary: mix(bgPrimary, other.bgPrimary),
      bgSecondary: mix(bgSecondary, other.bgSecondary),
      bgTertiary: mix(bgTertiary, other.bgTertiary),
      borderDefault: mix(borderDefault, other.borderDefault),
      gridEmpty: mix(gridEmpty, other.gridEmpty),
      gridFilled: mix(gridFilled, other.gridFilled),
      actionGreen: mix(actionGreen, other.actionGreen),
      actionGreenBorder: mix(actionGreenBorder, other.actionGreenBorder),
      successSubtle: mix(successSubtle, other.successSubtle),
      dangerRed: mix(dangerRed, other.dangerRed),
      warning: mix(warning, other.warning),
      accentBlue: mix(accentBlue, other.accentBlue),
      textPrimary: mix(textPrimary, other.textPrimary),
      textBody: mix(textBody, other.textBody),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
    );
  }
}
