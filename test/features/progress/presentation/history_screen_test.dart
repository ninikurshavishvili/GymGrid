import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/app/router.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/photo_locator.dart';
import 'package:gym_grid/features/progress/domain/entities/history_month.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_history.dart';
import 'package:gym_grid/features/progress/presentation/history_cubit.dart';
import 'package:gym_grid/features/progress/presentation/history_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_themed.dart';

class _MockWatchHistory extends Mock implements WatchHistory {}

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
  late _MockWatchHistory watchHistory;

  setUp(() => watchHistory = _MockWatchHistory());

  CheckIn checkInOn(
    CalendarDay day, {
    WorkoutType workoutType = WorkoutType.strength,
    OtherActivity? activity,
    String? note,
    String? photoPath,
    Rating? effort,
    Rating? energy,
  }) {
    return CheckIn(
      id: '$day',
      date: day,
      photoPaths: [photoPath ?? 'photos/$day.jpg'],
      workoutType: workoutType,
      activity: activity,
      note: note,
      effort: effort,
      energy: energy,
      createdAt: day.toLocalDateTime().add(
        const Duration(hours: 7, minutes: 42),
      ),
    );
  }

  final nov6 = CalendarDay(2026, 11, 6);
  final nov2 = CalendarDay(2026, 11, 2);
  final oct30 = CalendarDay(2026, 10, 30);

  void stubHistory(Stream<List<HistoryMonth>> Function() stream) {
    when(() => watchHistory()).thenAnswer((_) => stream());
  }

  void stubCheckIns(List<CheckIn> checkIns) {
    stubHistory(() => Stream.value(HistoryMonth.group(checkIns)));
  }

  /// Pumps the history screen over a stand-in home, with a stand-in for
  /// the day it opens.
  Future<void> pumpHistory(
    WidgetTester tester, {
    double textScale = 1,
    Size screen = phoneScreen,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Text('home'),
          routes: [
            GoRoute(
              path: 'history',
              builder: (context, state) => BlocProvider(
                create: (_) =>
                    HistoryCubit(watchHistory: watchHistory)..watch(),
                child: const HistoryScreen(photoLocator: _FakePhotoLocator()),
              ),
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

    await pumpScreen(tester, router, textScale: textScale, screen: screen);
    unawaited(router.push(AppRoutes.history));
    // Long enough for the page transition. Not pumpAndSettle, which a
    // spinning activity indicator would never let finish.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('states', () {
    testWidgets('shows a spinner until the check-ins arrive', (tester) async {
      final history = StreamController<List<HistoryMonth>>.broadcast();
      addTearDown(history.close);
      stubHistory(() => history.stream);

      await pumpHistory(tester);

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('says so when there are no check-ins', (tester) async {
      stubCheckIns(const []);

      await pumpHistory(tester);

      expect(find.text('History'), findsWidgets);
      expect(find.text('No check-ins yet'), findsOneWidget);
    });

    testWidgets('a failure offers to try again, which reloads', (tester) async {
      var calls = 0;
      stubHistory(
        () => ++calls == 1
            ? Stream.error(const StorageFailure())
            : Stream.value(HistoryMonth.group([checkInOn(nov6)])),
      );

      await pumpHistory(tester);
      expect(find.text("Couldn't load your check-ins"), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your check-ins"), findsNothing);
      expect(find.text('Strength'), findsOneWidget);
    });

    testWidgets('updates by itself when a check-in changes', (tester) async {
      final history = StreamController<List<HistoryMonth>>.broadcast();
      addTearDown(history.close);
      stubHistory(() => history.stream);
      await pumpHistory(tester);

      history.add(HistoryMonth.group([checkInOn(nov6)]));
      await tester.pumpAndSettle();
      expect(find.text('Strength'), findsOneWidget);

      history.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('Strength'), findsNothing);
      expect(find.text('No check-ins yet'), findsOneWidget);
    });
  });

  group('content', () {
    testWidgets('a section per month, newest first, each with its count', (
      tester,
    ) async {
      stubCheckIns([checkInOn(oct30), checkInOn(nov2), checkInOn(nov6)]);

      await pumpHistory(tester);

      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('2 check-ins'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('1 check-in'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('November 2026')).dy,
        lessThan(tester.getTopLeft(find.text('October 2026')).dy),
      );
      expect(
        tester.getTopLeft(find.textContaining('Nov 6')).dy,
        lessThan(tester.getTopLeft(find.textContaining('Nov 2')).dy),
      );
    });

    testWidgets("a row shows the title, day and time, and the note's first "
        'line', (tester) async {
      stubCheckIns([checkInOn(nov6, note: 'Deadlift PR\nand a long walk')]);

      await pumpHistory(tester);

      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Fri, Nov 6 · 7:42 AM'), findsOneWidget);
      expect(find.text('Deadlift PR'), findsOneWidget);
    });

    testWidgets('a row shows its ratings, when there are any', (tester) async {
      stubCheckIns([
        checkInOn(nov6, effort: Rating.high, energy: Rating.low),
        checkInOn(nov2, effort: Rating.medium),
        checkInOn(oct30),
      ]);

      await pumpHistory(tester);

      expect(find.text('Effort 80% · Energy 40%'), findsOneWidget);
      expect(find.text('Effort 60%'), findsOneWidget);
      expect(find.textContaining('Effort'), findsNWidgets(2));
    });

    testWidgets('an Other workout is named by its activity', (tester) async {
      stubCheckIns([
        checkInOn(
          nov6,
          workoutType: WorkoutType.other,
          activity: OtherActivity.sport,
        ),
        checkInOn(nov2, workoutType: WorkoutType.other),
      ]);

      await pumpHistory(tester);

      expect(find.text('Sport'), findsOneWidget);
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
    });

    testWidgets('survives a photo path it cannot locate', (tester) async {
      stubCheckIns([checkInOn(nov6, photoPath: '../outside.jpg')]);

      await pumpHistory(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Strength'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('a row opens its day', (tester) async {
      stubCheckIns([checkInOn(oct30), checkInOn(nov6)]);
      await pumpHistory(tester);

      await tester.tap(find.textContaining('Oct 30'));
      await tester.pumpAndSettle();

      expect(find.text('day 2026-10-30'), findsOneWidget);
    });

    testWidgets('Back returns to the previous screen', (tester) async {
      stubCheckIns([checkInOn(nov6)]);
      await pumpHistory(tester);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('a row is one button that reads out the whole check-in', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      stubCheckIns([checkInOn(nov6, note: 'Deadlift PR\nand more')]);

      await pumpHistory(tester);

      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            'Strength, Friday, November 6, 2026, 7:42 AM, Deadlift PR',
          ),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('a row reads out its ratings before the note', (tester) async {
      final semantics = tester.ensureSemantics();
      stubCheckIns([
        checkInOn(
          nov6,
          note: 'Deadlift PR',
          effort: Rating.high,
          energy: Rating.low,
        ),
      ]);

      await pumpHistory(tester);

      expect(
        find.bySemanticsLabel(
          'Strength, Friday, November 6, 2026, 7:42 AM, Effort 80%, '
          'Energy 40%, Deadlift PR',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('month headings are headers, with their count', (tester) async {
      final semantics = tester.ensureSemantics();
      stubCheckIns([checkInOn(nov6)]);

      await pumpHistory(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('November 2026, 1 check-in')),
        isSemantics(isHeader: true),
      );
      semantics.dispose();
    });

    testWidgets('every control has a label and a comfortable target', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      stubCheckIns([checkInOn(nov2), checkInOn(nov6, note: 'Legs')]);
      await pumpHistory(tester);

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('text has enough contrast', (tester) async {
      final semantics = tester.ensureSemantics();
      stubCheckIns([checkInOn(nov2), checkInOn(nov6, note: 'Legs')]);
      await pumpHistory(tester);

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });

  group('on the smallest iPhone at 3x text size', () {
    Future<void> expectFits(WidgetTester tester) async {
      await pumpHistory(tester, textScale: 3, screen: smallestPhoneScreen);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('a list with long notes fits', (tester) async {
      stubCheckIns([
        checkInOn(oct30, note: 'A long note ' * 20),
        checkInOn(nov2, workoutType: WorkoutType.mobility),
        checkInOn(nov6, note: 'Deadlift PR'),
      ]);

      await expectFits(tester);
    });

    testWidgets('the empty message fits', (tester) async {
      stubCheckIns(const []);

      await expectFits(tester);
    });

    testWidgets('the failure message fits', (tester) async {
      stubHistory(() => Stream.error(const StorageFailure()));

      await expectFits(tester);
    });

    testWidgets("a row's photo moves above the text, so words stay whole", (
      tester,
    ) async {
      stubCheckIns([checkInOn(nov6, workoutType: WorkoutType.mobility)]);

      await pumpHistory(tester, textScale: 3, screen: smallestPhoneScreen);

      expect(
        tester.getTopLeft(find.text('Mobility')).dy,
        greaterThan(tester.getBottomLeft(find.byType(Image)).dy),
      );
    });
  });
}
