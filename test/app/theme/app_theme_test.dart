import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/app/theme/app_theme.dart';

void main() {
  group('AppColors.dark', () {
    test('uses the iOS dark system colours', () {
      const colors = AppColors.dark;

      expect(colors.bgPrimary, const Color(0xFF000000));
      expect(colors.bgSecondary, const Color(0xFF1C1C1E));
      expect(colors.gridFilled, const Color(0xFF30D158));
      expect(colors.dangerRed, const Color(0xFFFF453A));
      expect(colors.warning, const Color(0xFFFF9F0A));
    });

    test('labels on green are black, which reads on that bright a fill', () {
      const colors = AppColors.dark;

      expect(colors.onAction, const Color(0xFF000000));
      expect(
        colors.actionGreen.computeLuminance(),
        greaterThan(0.4),
        reason: 'white text would fall below a 3:1 contrast ratio',
      );
    });
  });

  group('AppTextStyles.standard', () {
    const text = AppTextStyles.standard;

    void expectStyle(TextStyle style, String family, double size, int weight) {
      expect(style.fontFamily, family);
      expect(style.fontSize, size);
      expect(
        style.fontWeight,
        FontWeight.values.firstWhere((w) => w.value == weight),
      );
    }

    test("matches Apple's Dynamic Type styles", () {
      expectStyle(text.header, AppFonts.display, 20, 600);
      expectStyle(text.stat, AppFonts.display, 34, 700);
      expectStyle(text.badge, AppFonts.text, 12, 400);
      expectStyle(text.body, AppFonts.text, 17, 400);
      expectStyle(text.bodyStrong, AppFonts.text, 17, 600);
      expectStyle(text.footnote, AppFonts.text, 13, 400);
      expectStyle(text.button, AppFonts.text, 17, 600);
    });

    test('counts use figures of equal width', () {
      const tabular = FontFeature.tabularFigures();

      expect(text.stat.fontFeatures, contains(tabular));
      expect(text.footnote.fontFeatures, contains(tabular));
    });
  });

  group('AppTheme.dark', () {
    final theme = AppTheme.dark;

    test('maps tokens onto the Material colour scheme', () {
      const colors = AppColors.dark;

      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, colors.actionGreen);
      expect(theme.colorScheme.onPrimary, colors.onAction);
      expect(theme.colorScheme.error, colors.dangerRed);
      expect(theme.colorScheme.surface, colors.bgPrimary);
      expect(theme.scaffoldBackgroundColor, colors.bgPrimary);
    });

    test('controls dim when pressed instead of showing a ripple', () {
      expect(theme.splashFactory, NoSplash.splashFactory);
    });

    testWidgets('exposes tokens through BuildContext', (tester) async {
      late AppColors colors;
      late AppTextStyles textStyles;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              colors = context.colors;
              textStyles = context.textStyles;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(colors, AppColors.dark);
      expect(textStyles, AppTextStyles.standard);
    });
  });
}
