import 'package:flutter/material.dart';

/// Font family names, matching the `family` entries in pubspec.yaml.
abstract final class AppFonts {
  /// UI text.
  static const String inter = 'Inter';

  /// Numbers, labels and badges.
  static const String mono = 'JetBrainsMono';
}

/// GymGrid's type scale, read in widgets through `context.textStyles`.
///
/// Styles carry no colour. Widgets pick a colour token with
/// `copyWith(color: ...)`, or inherit one from the surrounding
/// [DefaultTextStyle]. Sizes are in logical pixels and Flutter scales them
/// with the system text size (Dynamic Type on iOS), so no style here fixes
/// a line height in pixels.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.header,
    required this.stat,
    required this.badge,
    required this.body,
    required this.bodyStrong,
    required this.monoBody,
    required this.button,
  });

  static const AppTextStyles standard = AppTextStyles(
    header: TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    stat: TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
    badge: TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    body: TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    bodyStrong: TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    monoBody: TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: 12,
      fontWeight: FontWeight.w400,
    ),
    button: TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );

  /// Screen titles. Inter 18 bold.
  final TextStyle header;

  /// Streak counts. JetBrains Mono 20 bold.
  final TextStyle stat;

  /// Labels, badges, dates and grid axis labels. JetBrains Mono 10 medium.
  final TextStyle badge;

  /// Body copy and notes. Inter 12 regular.
  final TextStyle body;

  /// Card titles and navigation titles. Inter 12 semibold.
  final TextStyle bodyStrong;

  /// Inline numbers next to body text, such as "days" or "58 / 280".
  /// JetBrains Mono 12 regular.
  final TextStyle monoBody;

  /// Button labels. Inter 14 semibold.
  final TextStyle button;

  @override
  AppTextStyles copyWith({
    TextStyle? header,
    TextStyle? stat,
    TextStyle? badge,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? monoBody,
    TextStyle? button,
  }) {
    return AppTextStyles(
      header: header ?? this.header,
      stat: stat ?? this.stat,
      badge: badge ?? this.badge,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      monoBody: monoBody ?? this.monoBody,
      button: button ?? this.button,
    );
  }

  @override
  AppTextStyles lerp(AppTextStyles? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AppTextStyles(
      header: mix(header, other.header),
      stat: mix(stat, other.stat),
      badge: mix(badge, other.badge),
      body: mix(body, other.body),
      bodyStrong: mix(bodyStrong, other.bodyStrong),
      monoBody: mix(monoBody, other.monoBody),
      button: mix(button, other.button),
    );
  }
}
