import 'package:flutter/material.dart';

/// The system font, under the names Flutter's Cupertino widgets use for it.
///
/// On iOS these are San Francisco in Apple's two optical sizes. Other
/// platforms fall back to their own default font.
abstract final class AppFonts {
  /// SF Pro Text, drawn for sizes below 20 points.
  static const String text = 'CupertinoSystemText';

  /// SF Pro Display, drawn for 20 points and up.
  static const String display = 'CupertinoSystemDisplay';
}

/// GymGrid's type scale, read in widgets through `context.textStyles`.
///
/// Sizes and weights follow Apple's Dynamic Type styles at the default text
/// size; each doc comment names the style it matches. Letter spacing is
/// Apple's tracking for each size, which UIKit applies by itself and Flutter
/// leaves to the app. Styles carry no colour. Widgets pick a colour token with `copyWith(color: ...)`, or
/// inherit one from the surrounding [DefaultTextStyle]. Flutter scales these
/// sizes with the system text size, so no style fixes a line height in
/// pixels.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.header,
    required this.stat,
    required this.badge,
    required this.body,
    required this.bodyStrong,
    required this.footnote,
    required this.button,
  });

  static const AppTextStyles standard = AppTextStyles(
    header: TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.38,
    ),
    stat: TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    badge: TextStyle(
      fontFamily: AppFonts.text,
      fontSize: 12,
      fontWeight: FontWeight.w400,
    ),
    body: TextStyle(
      fontFamily: AppFonts.text,
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.41,
      height: 1.3,
    ),
    bodyStrong: TextStyle(
      fontFamily: AppFonts.text,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.41,
      height: 1.3,
    ),
    footnote: TextStyle(
      fontFamily: AppFonts.text,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    button: TextStyle(
      fontFamily: AppFonts.text,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.41,
    ),
  );

  /// Section titles. Title 3: 20 semibold.
  final TextStyle header;

  /// Streak counts, with figures of equal width (`.monospacedDigit()`) so a
  /// changing count doesn't shift. Large Title size: 34 bold.
  final TextStyle stat;

  /// Small labels such as grid axes and photo captions. Caption 1: 12.
  final TextStyle badge;

  /// Long-form text such as notes. Body: 17.
  final TextStyle body;

  /// Row titles and navigation titles. Headline: 17 semibold.
  final TextStyle bodyStrong;

  /// Supporting text, such as subtitles, dates and counts. Footnote: 13,
  /// with figures of equal width.
  final TextStyle footnote;

  /// Button labels. 17 semibold.
  final TextStyle button;

  @override
  AppTextStyles copyWith({
    TextStyle? header,
    TextStyle? stat,
    TextStyle? badge,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? footnote,
    TextStyle? button,
  }) {
    return AppTextStyles(
      header: header ?? this.header,
      stat: stat ?? this.stat,
      badge: badge ?? this.badge,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      footnote: footnote ?? this.footnote,
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
      footnote: mix(footnote, other.footnote),
      button: mix(button, other.button),
    );
  }
}
