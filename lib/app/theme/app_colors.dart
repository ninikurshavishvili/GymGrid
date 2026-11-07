import 'package:flutter/material.dart';

/// GymGrid's colour tokens, read in widgets through `context.colors`.
///
/// The values are Apple's dark system colours (`systemBackground`,
/// `systemGreen` and so on), on the true black of the Fitness app. They are
/// fixed rather than read from the system so GymGrid looks the same in both
/// appearances, and so no screen needs a raw hex.
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
    required this.onAction,
    required this.successSubtle,
    required this.dangerRed,
    required this.warning,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.textMuted,
    required this.overlayScrim,
    required this.overlayBorder,
    required this.chartEffort,
    required this.chartEnergy,
  });

  static const AppColors dark = AppColors(
    bgPrimary: Color(0xFF000000),
    bgSecondary: Color(0xFF1C1C1E),
    bgTertiary: Color(0xFF2C2C2E),
    borderDefault: Color(0xFF38383A),
    gridEmpty: Color(0xFF2C2C2E),
    gridFilled: Color(0xFF30D158),
    actionGreen: Color(0xFF30D158),
    actionGreenBorder: Color(0xFF30D158),
    onAction: Color(0xFF000000),
    successSubtle: Color(0x2630D158),
    dangerRed: Color(0xFFFF453A),
    warning: Color(0xFFFF9F0A),
    textPrimary: Color(0xFFFFFFFF),
    textBody: Color(0xFFEBEBF5),
    textSecondary: Color(0xFF8E8E93),
    textMuted: Color(0xFF48484A),
    overlayScrim: Color(0xB3000000),
    overlayBorder: Color(0x1AFFFFFF),
    chartEffort: Color(0xFF30D158),
    chartEnergy: Color(0xFF0A84FF),
  );

  /// Screen background.
  final Color bgPrimary;

  /// Cards, inputs and dialogs.
  final Color bgSecondary;

  /// Secondary buttons, icon wells and hairline dividers.
  final Color bgTertiary;

  /// Outlines where an edge is needed, such as inputs.
  final Color borderDefault;

  /// A grid day without a check-in.
  final Color gridEmpty;

  /// A grid day with a check-in.
  final Color gridFilled;

  /// Primary buttons and the selected workout chip.
  final Color actionGreen;

  /// Outline for green elements: selected chip, pending today.
  final Color actionGreenBorder;

  /// Labels on [actionGreen]. Black, as in Fitness: white on this bright a
  /// green doesn't have enough contrast to read.
  final Color onAction;

  /// Background behind green text, such as badges.
  final Color successSubtle;

  /// Destructive actions.
  final Color dangerRed;

  /// The "at risk" streak state.
  final Color warning;

  /// Headings, numbers and button labels.
  final Color textPrimary;

  /// Long-form text such as notes.
  final Color textBody;

  /// Labels and supporting text.
  final Color textSecondary;

  /// De-emphasised text, such as labels on an empty grid.
  final Color textMuted;

  /// Translucent backing for labels and buttons drawn over photos. Fixed
  /// rather than derived from the theme because it must read on any image.
  final Color overlayScrim;

  /// Hairline outline around [overlayScrim] elements.
  final Color overlayBorder;

  /// The effort line on the Trends chart: the app's green, drawn solid.
  final Color chartEffort;

  /// The energy line on the Trends chart: Apple's blue, drawn dashed, so
  /// the two lines differ by more than colour.
  final Color chartEnergy;

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
    Color? onAction,
    Color? successSubtle,
    Color? dangerRed,
    Color? warning,
    Color? textPrimary,
    Color? textBody,
    Color? textSecondary,
    Color? textMuted,
    Color? overlayScrim,
    Color? overlayBorder,
    Color? chartEffort,
    Color? chartEnergy,
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
      onAction: onAction ?? this.onAction,
      successSubtle: successSubtle ?? this.successSubtle,
      dangerRed: dangerRed ?? this.dangerRed,
      warning: warning ?? this.warning,
      textPrimary: textPrimary ?? this.textPrimary,
      textBody: textBody ?? this.textBody,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      overlayBorder: overlayBorder ?? this.overlayBorder,
      chartEffort: chartEffort ?? this.chartEffort,
      chartEnergy: chartEnergy ?? this.chartEnergy,
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
      onAction: mix(onAction, other.onAction),
      successSubtle: mix(successSubtle, other.successSubtle),
      dangerRed: mix(dangerRed, other.dangerRed),
      warning: mix(warning, other.warning),
      textPrimary: mix(textPrimary, other.textPrimary),
      textBody: mix(textBody, other.textBody),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      overlayScrim: mix(overlayScrim, other.overlayScrim),
      overlayBorder: mix(overlayBorder, other.overlayBorder),
      chartEffort: mix(chartEffort, other.chartEffort),
      chartEnergy: mix(chartEnergy, other.chartEnergy),
    );
  }
}
