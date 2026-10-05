import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/app/theme/app_theme.dart';
import 'package:gym_grid/core/widgets/streak_card.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('shows the uppercased label and the day count', (tester) async {
    await pumpThemed(
      tester,
      const StreakCard(label: 'Longest streak', days: 42),
    );

    expect(find.text('LONGEST STREAK', findRichText: true), findsOneWidget);
    expect(find.text('42 days', findRichText: true), findsOneWidget);
  });

  testWidgets('uses the singular unit for one day', (tester) async {
    await pumpThemed(
      tester,
      const StreakCard(label: 'Current streak', days: 1),
    );

    expect(find.text('1 day', findRichText: true), findsOneWidget);
  });

  testWidgets('announces label and count as one phrase', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpThemed(
      tester,
      const StreakCard(label: 'Current streak', days: 14),
    );

    expect(find.bySemanticsLabel('Current streak: 14 days'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('at risk shows a warning label but keeps the spoken label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpThemed(
      tester,
      const StreakCard(label: 'Current streak', days: 14, isAtRisk: true),
    );

    final label = tester.widget<RichText>(
      find.text('AT RISK', findRichText: true),
    );
    expect(label.text.style?.color, AppColors.dark.warning);
    expect(
      find.bySemanticsLabel('Current streak: 14 days, at risk'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('two cards side by side fit at 3x text size', (tester) async {
    await pumpThemed(
      tester,
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: StreakCard(label: 'Current streak', days: 14)),
          SizedBox(width: 10),
          Expanded(child: StreakCard(label: 'Longest streak', days: 365)),
        ],
      ),
      textScale: 3,
    );

    expect(tester.takeException(), isNull);
  });
}
