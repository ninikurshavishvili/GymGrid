import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_text_styles.dart';

export 'app_colors.dart';
export 'app_dimens.dart';
export 'app_text_styles.dart';

/// Builds the app's single dark theme from the GymGrid tokens.
///
/// The tokens are mapped onto Material's [ColorScheme] and component themes
/// so stock widgets (text fields, dialogs, app bars, snack bars) match the
/// design without per-screen styling. GymGrid-specific tokens travel
/// alongside as [ThemeExtension]s.
abstract final class AppTheme {
  /// Light status bar and a matching Android navigation bar.
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get dark {
    const colors = AppColors.dark;
    const text = AppTextStyles.standard;

    // Built by hand rather than with ColorScheme.fromSeed: a seed generates
    // its own tonal palette, which would drift from the design's exact hexes.
    final colorScheme = ColorScheme.dark(
      primary: colors.actionGreen,
      onPrimary: colors.onAction,
      secondary: colors.actionGreenBorder,
      onSecondary: colors.onAction,
      error: colors.dangerRed,
      onError: colors.textPrimary,
      surface: colors.bgPrimary,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceContainerLowest: colors.bgPrimary,
      surfaceContainerLow: colors.bgSecondary,
      surfaceContainer: colors.bgSecondary,
      surfaceContainerHigh: colors.bgSecondary,
      surfaceContainerHighest: colors.bgTertiary,
      outline: colors.borderDefault,
      outlineVariant: colors.bgTertiary,
      // Material 3 tints raised surfaces with the primary colour; the design
      // uses flat surfaces.
      surfaceTint: Colors.transparent,
    );

    // Filled like the app's cards, with no outline. The caret shows focus.
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: AppFonts.text,
      // iOS controls dim when pressed; they don't ripple.
      splashFactory: NoSplash.splashFactory,
      highlightColor: colors.overlayBorder,
      scaffoldBackgroundColor: colors.bgPrimary,
      textTheme: TextTheme(
        titleLarge: text.header,
        titleMedium: text.bodyStrong,
        bodyLarge: text.body,
        bodyMedium: text.body,
        labelLarge: text.button,
        labelSmall: text.badge,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.bgPrimary,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.bodyStrong.copyWith(color: colors.textPrimary),
        systemOverlayStyle: systemOverlayStyle,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.actionGreen,
          foregroundColor: colors.onAction,
          disabledBackgroundColor: colors.bgTertiary,
          disabledForegroundColor: colors.textMuted,
          textStyle: text.button,
          minimumSize: const Size(64, 52),
          // Vertical padding keeps wrapped labels off the edges at large
          // text sizes; minimumSize sets the height at normal sizes.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const StadiumBorder(),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      // Text buttons read as links, in the app's one accent colour.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.actionGreen,
          textStyle: text.bodyStrong,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.bgTertiary,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colors.textSecondary, size: 20),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.bgSecondary,
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        hintStyle: text.body.copyWith(color: colors.textSecondary),
        counterStyle: text.footnote.copyWith(color: colors.textSecondary),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.actionGreenBorder,
        selectionColor: colors.actionGreen.withValues(alpha: 0.4),
        selectionHandleColor: colors.actionGreenBorder,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.bgSecondary,
        barrierColor: colors.bgPrimary.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.bgTertiary,
        contentTextStyle: text.body.copyWith(color: colors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.actionGreenBorder,
      ),
      extensions: const <ThemeExtension<dynamic>>[colors, text],
    );
  }
}

/// Shorthand for reading GymGrid tokens, e.g. `context.colors.bgSecondary`.
///
/// The iOS equivalent is `UIColor(named:)` backed by an asset catalog: widgets
/// ask for a named token and the theme decides the value.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  AppTextStyles get textStyles => Theme.of(this).extension<AppTextStyles>()!;

  /// Whether text is at one of iOS's accessibility sizes, where layouts
  /// should stack rather than sit side by side. The counterpart of SwiftUI's
  /// `dynamicTypeSize.isAccessibilitySize`.
  bool get usesAccessibilityTextSize =>
      MediaQuery.textScalerOf(this).scale(1) >= 1.6;
}
