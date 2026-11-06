import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/app/app.dart';
import 'package:gym_grid/app/di.dart';
import 'package:gym_grid/app/router.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/date/clock.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/check_in/domain/repositories/photo_locator.dart';
import 'package:gym_grid/features/check_in/domain/usecases/get_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/save_check_in.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_screen.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_progress.dart';
import 'package:gym_grid/features/progress/presentation/day_detail_screen.dart';
import 'package:gym_grid/features/progress/presentation/home_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

class _MockPhotoLocator extends Mock implements PhotoLocator {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

void main() {
  late GoRouter router;

  setUpAll(() => registerFallbackValue(CalendarDay(2000, 1, 1)));

  setUp(() {
    // Route builders take their dependencies from the container.
    final repository = _MockCheckInRepository();
    when(repository.watchAll).thenAnswer((_) => Stream.value(const []));
    when(() => repository.findByDate(any())).thenAnswer((_) async => null);
    const clock = Clock();
    getIt
      ..registerSingleton<Clock>(clock)
      ..registerSingleton(WatchProgress(repository: repository, clock: clock))
      ..registerSingleton(SaveCheckIn(repository: repository, clock: clock))
      ..registerSingleton(GetCheckIn(repository: repository))
      ..registerSingleton<PhotoPicker>(_MockPhotoPicker())
      ..registerSingleton<PhotoLocator>(_MockPhotoLocator());
    router = createRouter();
  });

  tearDown(() async {
    router.dispose();
    await getIt.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(GymGridApp(router: router));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the home screen', (tester) async {
    await pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('check-in opens over home and Cancel closes it', (tester) async {
    await pumpApp(tester);

    unawaited(router.push(AppRoutes.checkIn));
    await tester.pumpAndSettle();
    expect(find.byType(CheckInScreen), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckInScreen), findsNothing);
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
