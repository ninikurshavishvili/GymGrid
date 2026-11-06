import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/app/router.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/photo_locator.dart';
import 'package:gym_grid/features/progress/domain/entities/progress.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_progress.dart';
import 'package:gym_grid/features/progress/presentation/home_cubit.dart';
import 'package:gym_grid/features/progress/presentation/home_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_themed.dart';

class _MockWatchProgress extends Mock implements WatchProgress {}

/// Rejects anything outside `photos/`, as `PhotoStore` does.
class _FakePhotoLocator implements PhotoLocator {
  const _FakePhotoLocator();

  @override
  Uri uriOf(String photoPath) {
    if (!photoPath.startsWith('photos/')) throw ArgumentError(photoPath);
    return Uri.file('/no/such/folder/$photoPath');
  }
}

void main() {
  late _MockWatchProgress watchProgress;

  final today = CalendarDay(2026, 11, 6);

  setUp(() => watchProgress = _MockWatchProgress());

  CheckIn checkInOn(
    CalendarDay day, {
    WorkoutType workoutType = WorkoutType.strength,
    String? note,
    String? photoPath,
  }) {
    return CheckIn(
      id: '$day',
      date: day,
      photoPaths: [photoPath ?? 'photos/$day.jpg'],
      workoutType: workoutType,
      note: note,
      createdAt: day.toLocalDateTime().add(
        const Duration(hours: 7, minutes: 42),
      ),
    );
  }

  Progress progressWith(List<CheckIn> checkIns, {CalendarDay? asOf}) =>
      Progress.from(checkIns, today: asOf ?? today);

  void stubProgress(Stream<Progress> Function() stream) {
    when(() => watchProgress()).thenAnswer((_) => stream());
  }

  /// Pumps the home screen with stand-ins for the screens it opens.
  Future<void> pumpHome(WidgetTester tester, {double textScale = 1}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => BlocProvider(
            create: (_) => HomeCubit(watchProgress: watchProgress)..watch(),
            child: const HomeScreen(photoLocator: _FakePhotoLocator()),
          ),
          routes: [
            GoRoute(
              path: 'check-in',
              builder: (context, state) => const Text('check-in screen'),
            ),
            GoRoute(
              path: 'day/:date',
              builder: (context, state) =>
                  Text('day ${state.pathParameters['date']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScreen(tester, router, textScale: textScale);
    await tester.pump();
  }

  Finder sideways() => find.byWidgetPredicate(
    (widget) => widget is Scrollable && widget.axis == Axis.horizontal,
  );

  group('states', () {
    testWidgets('shows a spinner until progress arrives', (tester) async {
      final progress = StreamController<Progress>();
      addTearDown(progress.close);
      stubProgress(() => progress.stream);

      await pumpHome(tester);

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('Check in'), findsNothing);
    });

    testWidgets('a first launch shows empty counts and the check-in button', (
      tester,
    ) async {
      stubProgress(() => Stream.value(progressWith(const [])));

      await pumpHome(tester);

      expect(find.text('GymGrid'), findsWidgets);
      expect(find.text('Fri, Nov 6'), findsOneWidget);
      expect(
        find.textContaining('Current streak', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('0 days', findRichText: true), findsNWidgets(2));
      expect(find.text('0 check-ins'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('No check-in yet'), findsOneWidget);
      expect(find.text('Check in'), findsOneWidget);
    });

    testWidgets('warns when the streak is at risk', (tester) async {
      stubProgress(
        () => Stream.value(
          progressWith([
            checkInOn(today.addDays(-2)),
            checkInOn(today.addDays(-1)),
          ]),
        ),
      );

      await pumpHome(tester);

      expect(
        find.textContaining('At risk', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Check in to keep your 2-day streak'), findsOneWidget);
      expect(find.text('Check in'), findsOneWidget);
    });

    testWidgets("once checked in, shows today's check-in instead of the "
        'button', (tester) async {
      stubProgress(
        () => Stream.value(
          progressWith([
            checkInOn(
              today,
              workoutType: WorkoutType.cardio,
              note: 'Intervals\nand a long cool-down',
            ),
          ]),
        ),
      );

      await pumpHome(tester);

      expect(find.text('Cardio'), findsOneWidget);
      expect(find.text('Checked in at 7:42 AM'), findsOneWidget);
      expect(find.text('Intervals'), findsOneWidget);
      expect(find.text('Check in'), findsNothing);
      expect(find.text('1 check-in'), findsOneWidget);
    });

    testWidgets('updates by itself when a check-in arrives', (tester) async {
      final progress = StreamController<Progress>();
      addTearDown(progress.close);
      stubProgress(() => progress.stream);
      await pumpHome(tester);

      progress.add(progressWith(const []));
      await tester.pump();
      await tester.pump();
      expect(find.text('Check in'), findsOneWidget);

      progress.add(progressWith([checkInOn(today)]));
      await tester.pump();
      await tester.pump();
      expect(find.text('Check in'), findsNothing);
      expect(find.text('Strength'), findsOneWidget);
    });

    testWidgets('survives a photo path it cannot locate', (tester) async {
      stubProgress(
        () => Stream.value(
          progressWith([checkInOn(today, photoPath: '../outside.jpg')]),
        ),
      );

      await pumpHome(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Strength'), findsOneWidget);
    });

    testWidgets('a failure offers to try again, which reloads', (tester) async {
      var calls = 0;
      stubProgress(
        () => ++calls == 1
            ? Stream.error(const StorageFailure())
            : Stream.value(progressWith(const [])),
      );

      await pumpHome(tester);
      expect(find.text("Couldn't load your check-ins"), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      expect(find.text("Couldn't load your check-ins"), findsNothing);
      expect(find.text('No check-in yet'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('the button opens the check-in screen', (tester) async {
      stubProgress(() => Stream.value(progressWith(const [])));
      await pumpHome(tester);

      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();

      expect(find.text('check-in screen'), findsOneWidget);
    });

    testWidgets("today's row opens today", (tester) async {
      stubProgress(() => Stream.value(progressWith([checkInOn(today)])));
      await pumpHome(tester);

      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();

      expect(find.text('day 2026-11-06'), findsOneWidget);
    });

    testWidgets('a filled day in the grid opens that day', (tester) async {
      final semantics = tester.ensureSemantics();
      final yesterday = today.addDays(-1);
      stubProgress(() => Stream.value(progressWith([checkInOn(yesterday)])));
      await pumpHome(tester);

      await tester.tap(find.bySemanticsLabel('Nov 5, checked in, strength'));
      await tester.pumpAndSettle();

      expect(find.text('day 2026-11-05'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('year grid', () {
    testWidgets('opens on the current week', (tester) async {
      final semantics = tester.ensureSemantics();
      stubProgress(() => Stream.value(progressWith([checkInOn(today)])));

      await pumpHome(tester);

      final position = tester.state<ScrollableState>(sideways()).position;
      expect(position.pixels, greaterThan(0));
      final viewport = tester.getRect(sideways());
      final todaysCell = tester.getRect(
        find.bySemanticsLabel('Nov 6, checked in, strength'),
      );
      expect(viewport.contains(todaysCell.center), isTrue);
      semantics.dispose();
    });

    testWidgets('on 1 January it starts at the beginning', (tester) async {
      final newYearsDay = CalendarDay(2027, 1, 1);
      stubProgress(
        () => Stream.value(progressWith(const [], asOf: newYearsDay)),
      );

      await pumpHome(tester);

      expect(find.text('2027'), findsOneWidget);
      expect(tester.state<ScrollableState>(sideways()).position.pixels, 0);
    });

    testWidgets('on 31 December it stops at the end of the content', (
      tester,
    ) async {
      stubProgress(
        () => Stream.value(
          progressWith(const [], asOf: CalendarDay(2026, 12, 31)),
        ),
      );

      await pumpHome(tester);

      final position = tester.state<ScrollableState>(sideways()).position;
      expect(position.pixels, position.maxScrollExtent);
    });

    testWidgets('announces the year as a whole and each check-in day, but not '
        'empty days', (tester) async {
      final semantics = tester.ensureSemantics();
      stubProgress(
        () => Stream.value(
          progressWith([
            checkInOn(today.addDays(-1)),
            checkInOn(today, workoutType: WorkoutType.mobility),
          ]),
        ),
      );

      await pumpHome(tester);

      expect(
        find.bySemanticsLabel('2026 activity, 2 check-ins'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Nov 6, checked in, mobility'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r', checked in, ')),
        findsNWidgets(2),
      );
      semantics.dispose();
    });
  });

  group('at 3x text size', () {
    Future<void> expectNoOverflow(WidgetTester tester) async {
      await pumpHome(tester, textScale: 3);
      expect(tester.takeException(), isNull);

      // The list is built lazily, so scroll to lay out everything in it.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('a first launch fits', (tester) async {
      stubProgress(() => Stream.value(progressWith(const [])));

      await expectNoOverflow(tester);
    });

    testWidgets('a checked-in day with a long note fits', (tester) async {
      stubProgress(
        () => Stream.value(
          progressWith([
            checkInOn(today, note: 'A long note about the session' * 4),
          ]),
        ),
      );

      await expectNoOverflow(tester);
    });

    testWidgets('an at-risk streak fits', (tester) async {
      stubProgress(
        () => Stream.value(
          progressWith([
            for (var i = 1; i <= 200; i++) checkInOn(today.addDays(-i)),
          ]),
        ),
      );

      await expectNoOverflow(tester);
    });

    testWidgets('a failure fits', (tester) async {
      stubProgress(() => Stream.error(const StorageFailure()));

      await pumpHome(tester, textScale: 3);

      expect(tester.takeException(), isNull);
    });

    testWidgets("today's photo moves above the text, so words stay whole", (
      tester,
    ) async {
      stubProgress(() => Stream.value(progressWith([checkInOn(today)])));

      await pumpHome(tester, textScale: 3);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Strength')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(Image)).dy),
      );
    });

    testWidgets('streak cards stack instead of sharing a row', (tester) async {
      stubProgress(() => Stream.value(progressWith(const [])));

      await pumpHome(tester, textScale: 3);

      final current = find.textContaining('Current streak', findRichText: true);
      final longest = find.text('Longest streak', findRichText: true);
      expect(
        tester.getTopLeft(longest).dy,
        greaterThan(tester.getBottomLeft(current).dy),
      );
    });
  });

  testWidgets("today's photo sits beside the text at the default text size", (
    tester,
  ) async {
    stubProgress(() => Stream.value(progressWith([checkInOn(today)])));

    await pumpHome(tester);

    expect(
      tester.getCenter(find.text('Strength')).dx,
      greaterThan(tester.getTopRight(find.byType(Image)).dx),
    );
  });

  testWidgets('streak cards share a row at the default text size', (
    tester,
  ) async {
    stubProgress(() => Stream.value(progressWith(const [])));

    await pumpHome(tester);

    final current = find.textContaining('Current streak', findRichText: true);
    final longest = find.text('Longest streak', findRichText: true);
    expect(tester.getTopLeft(longest).dy, tester.getTopLeft(current).dy);
  });
}
