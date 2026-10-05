import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/widgets/primary_button.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('calls onPressed when tapped', (tester) async {
    var presses = 0;
    await pumpThemed(
      tester,
      PrimaryButton(
        label: 'Check in today',
        icon: Icons.photo_camera_outlined,
        onPressed: () => presses++,
      ),
    );

    await tester.tap(find.byType(PrimaryButton));

    expect(presses, 1);
  });

  testWidgets('is disabled without onPressed', (tester) async {
    await pumpThemed(
      tester,
      const PrimaryButton(label: 'Save check-in', onPressed: null),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('while loading shows a spinner, keeps the label, ignores taps', (
    tester,
  ) async {
    var presses = 0;
    await pumpThemed(
      tester,
      PrimaryButton(
        label: 'Save check-in',
        isLoading: true,
        onPressed: () => presses++,
      ),
    );

    await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save check-in'), findsOneWidget);
    expect(presses, 0);
  });

  testWidgets('a long label wraps at 3x text size instead of overflowing', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      PrimaryButton(
        label: 'Checked in today at 7:42 AM',
        icon: Icons.check_circle,
        onPressed: () {},
      ),
      textScale: 3,
    );

    expect(tester.takeException(), isNull);
  });
}
