import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/app/font_licenses.dart';
import 'package:gym_grid/app/theme/app_theme.dart';

void main() {
  group('AppColors.dark', () {
    test('matches the design spec tokens', () {
      const colors = AppColors.dark;

      expect(colors.bgPrimary, const Color(0xFF0D1117));
      expect(colors.bgSecondary, const Color(0xFF161B22));
      expect(colors.borderDefault, const Color(0xFF30363D));
      expect(colors.gridEmpty, const Color(0xFF21262D));
      expect(colors.gridFilled, const Color(0xFF39D353));
      expect(colors.actionGreen, const Color(0xFF238636));
      expect(colors.dangerRed, const Color(0xFFDA3633));
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

    test('matches the design type scale', () {
      expectStyle(text.header, AppFonts.inter, 18, 700);
      expectStyle(text.stat, AppFonts.mono, 20, 700);
      expectStyle(text.badge, AppFonts.mono, 10, 500);
      expectStyle(text.body, AppFonts.inter, 12, 400);
      expectStyle(text.button, AppFonts.inter, 14, 600);
    });
  });

  group('AppTheme.dark', () {
    final theme = AppTheme.dark;

    test('maps tokens onto the Material colour scheme', () {
      const colors = AppColors.dark;

      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, colors.actionGreen);
      expect(theme.colorScheme.error, colors.dangerRed);
      expect(theme.colorScheme.surface, colors.bgPrimary);
      expect(theme.scaffoldBackgroundColor, colors.bgPrimary);
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

  group('bundled fonts', () {
    test('font families and weights match AppFonts', () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json'))
              as List<dynamic>;
      final weightsByFamily = {
        for (final entry in manifest.cast<Map<String, dynamic>>())
          entry['family'] as String: {
            for (final font
                in (entry['fonts'] as List<dynamic>)
                    .cast<Map<String, dynamic>>())
              // Entries without a weight (e.g. MaterialIcons) are regular.
              font['weight'] as int? ?? 400,
          },
      };

      expect(weightsByFamily[AppFonts.inter], {400, 500, 600, 700});
      expect(weightsByFamily[AppFonts.mono], {400, 500, 700});
    });

    test('licences are registered', () async {
      registerFontLicenses();

      final packages = <String>{};
      await for (final entry in LicenseRegistry.licenses) {
        packages.addAll(entry.packages);
      }

      expect(packages, containsAll(['Inter', 'JetBrains Mono']));
    });
  });
}
