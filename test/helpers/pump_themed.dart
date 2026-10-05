import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/app/theme/app_theme.dart';

/// Pumps [child] inside the app theme on a 390x844 phone screen.
///
/// [textScale] simulates the system text size (Dynamic Type on iOS). Any
/// layout overflow throws during the pump and fails the test, so tests at a
/// large scale double as overflow checks. The real app fonts are loaded by
/// `flutter_test_config.dart`, so text is measured as on a device.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: child,
        ),
      ),
    ),
  );
}
