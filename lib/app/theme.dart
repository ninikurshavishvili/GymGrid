import 'package:flutter/material.dart';

/// App-wide visual configuration. GymGrid ships a single dark Material 3 theme.
abstract final class AppTheme {
  /// Seed for the generated Material 3 palette; a GitHub-contribution green.
  static const Color _seed = Color(0xFF2EA043);

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
      ),
      extensions: <ThemeExtension<dynamic>>[
        GridColors(
          empty: colorScheme.surfaceContainerHighest,
          filled: _seed,
          todayOutline: colorScheme.onSurface,
        ),
      ],
    );
  }
}

/// Colours used by the contribution grid painter.
///
/// A [ThemeExtension] lets custom widgets read app-specific tokens through
/// `Theme.of(context).extension<GridColors>()`, the same way built-in widgets
/// read the [ColorScheme].
@immutable
class GridColors extends ThemeExtension<GridColors> {
  const GridColors({
    required this.empty,
    required this.filled,
    required this.todayOutline,
  });

  final Color empty;
  final Color filled;
  final Color todayOutline;

  @override
  GridColors copyWith({Color? empty, Color? filled, Color? todayOutline}) {
    return GridColors(
      empty: empty ?? this.empty,
      filled: filled ?? this.filled,
      todayOutline: todayOutline ?? this.todayOutline,
    );
  }

  @override
  GridColors lerp(GridColors? other, double t) {
    if (other == null) return this;
    return GridColors(
      empty: Color.lerp(empty, other.empty, t)!,
      filled: Color.lerp(filled, other.filled, t)!,
      todayOutline: Color.lerp(todayOutline, other.todayOutline, t)!,
    );
  }
}
