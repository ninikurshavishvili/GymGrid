import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/app/theme/app_theme.dart';

/// A typical iPhone screen, in points.
const phoneScreen = Size(390, 844);

/// The smallest screen the app supports: iPhone SE.
const smallestPhoneScreen = Size(375, 667);

/// Pumps [child] inside the app theme on a 390x844 phone screen.
///
/// [textScale] simulates the system text size (Dynamic Type on iOS). Any
/// layout overflow throws during the pump and fails the test, so tests at a
/// large scale double as overflow checks. `flutter_test_config.dart` loads a
/// stand-in for the system font, so text is measured about as on a device.
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

/// Pumps whole screens through [router], on [screen].
///
/// For screens with their own `Scaffold`, which can't sit inside the scroll
/// view [pumpThemed] provides, and so that taps can navigate.
Future<void> pumpScreen(
  WidgetTester tester,
  GoRouter router, {
  double textScale = 1,
  Size screen = phoneScreen,
}) async {
  tester.view
    ..physicalSize = screen * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}
