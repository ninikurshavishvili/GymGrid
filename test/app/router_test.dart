import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/app/app.dart';
import 'package:gym_grid/app/router.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_screen.dart';
import 'package:gym_grid/features/progress/presentation/day_detail_screen.dart';
import 'package:gym_grid/features/progress/presentation/home_screen.dart';

void main() {
  late GoRouter router;

  setUp(() => router = createRouter());
  tearDown(() => router.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(GymGridApp(router: router));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the home screen', (tester) async {
    await pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('check-in button pushes the check-in screen and back pops it', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckInScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('day detail route passes the parsed day to the screen', (
    tester,
  ) async {
    await pumpApp(tester);

    router.go(AppRoutes.dayDetail(DateTime(2026, 2, 7)));
    await tester.pumpAndSettle();

    final screen = tester.widget<DayDetailScreen>(find.byType(DayDetailScreen));
    expect(screen.day, DateTime(2026, 2, 7));
  });

  testWidgets('deep link to day detail keeps home underneath', (tester) async {
    await pumpApp(tester);

    router.go(AppRoutes.dayDetail(DateTime(2026, 2, 7)));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
  });

  for (final location in ['/day/2026-13-01', '/day/2026-2-7', '/nowhere']) {
    testWidgets('shows not found for $location', (tester) async {
      await pumpApp(tester);

      router.go(location);
      await tester.pumpAndSettle();

      expect(find.text('Page not found'), findsOneWidget);
    });
  }
}
