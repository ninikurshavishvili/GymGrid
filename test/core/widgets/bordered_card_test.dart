import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/widgets/bordered_card.dart';
import 'package:gym_grid/core/widgets/dashed_border_painter.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('renders its child', (tester) async {
    await pumpThemed(tester, const BorderedCard(child: Text('Hello')));

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var taps = 0;
    await pumpThemed(
      tester,
      BorderedCard(onTap: () => taps++, child: const Text('Tap me')),
    );

    await tester.tap(find.byType(BorderedCard));

    expect(taps, 1);
  });

  testWidgets('a tappable card with a label is one activatable button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpThemed(
      tester,
      BorderedCard(
        onTap: () {},
        semanticLabel: 'Checked in today',
        child: const Text('ignored by screen readers'),
      ),
    );

    expect(
      tester.getSemantics(find.byType(BorderedCard)),
      isSemantics(
        label: 'Checked in today',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('ignored by screen readers'), findsNothing);
    semantics.dispose();
  });

  testWidgets('dashed variant paints a dashed outline', (tester) async {
    await pumpThemed(tester, const BorderedCard.dashed(child: Text('Empty')));

    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.foregroundPainter);
    expect(painters, contains(isA<DashedBorderPainter>()));
  });
}
