import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/app/router.dart';
import 'package:gym_grid/app/theme/app_colors.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/progress/domain/entities/trends.dart';
import 'package:gym_grid/features/progress/domain/usecases/watch_trends.dart';
import 'package:gym_grid/features/progress/presentation/trends_cubit.dart';
import 'package:gym_grid/features/progress/presentation/trends_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_themed.dart';

class _MockWatchTrends extends Mock implements WatchTrends {}

void main() {
  late _MockWatchTrends watchTrends;
  late List<String?> haptics;

  final today = CalendarDay(2026, 11, 7);
  const colors = AppColors.dark;

  CheckIn ago(int daysAgo, {Rating? effort, Rating? energy}) {
    final day = today.addDays(-daysAgo);
    return CheckIn(
      id: '$day',
      date: day,
      photoPaths: const ['photos/1.jpg'],
      workoutType: WorkoutType.strength,
      effort: effort,
      energy: energy,
      createdAt: day.toLocalDateTime(),
    );
  }

  /// A month of ratings: effort 60% then 80%, energy 40% then 60%, and a
  /// month before with effort at 40%.
  final rated = [
    ago(40, effort: Rating.low),
    ago(10, effort: Rating.medium, energy: Rating.low),
    ago(2, effort: Rating.high, energy: Rating.medium),
  ];

  void stubCheckIns(List<CheckIn> checkIns) {
    when(() => watchTrends(any())).thenAnswer(
      (invocation) => Stream.value(
        Trends.from(
          checkIns,
          range: invocation.positionalArguments.single as TrendRange,
          today: today,
        ),
      ),
    );
  }

  setUpAll(() => registerFallbackValue(TrendRange.month));

  setUp(() {
    watchTrends = _MockWatchTrends();
    haptics = [];
    stubCheckIns(rated);
  });

  /// Pumps the Trends screen over a stand-in home.
  Future<void> pumpTrends(
    WidgetTester tester, {
    double textScale = 1,
    Size screen = phoneScreen,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String?);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Text('home'),
          routes: [
            GoRoute(
              path: 'trends',
              builder: (context, state) => BlocProvider(
                create: (_) => TrendsCubit(watchTrends: watchTrends)..watch(),
                child: const TrendsScreen(),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScreen(tester, router, textScale: textScale, screen: screen);
    unawaited(router.push(AppRoutes.trends));
    // Long enough for the page transition. Not pumpAndSettle, which a
    // spinning activity indicator would never let finish.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  List<LineChartBarData> bars(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData;

  /// The toggle for [name]'s line, found by what VoiceOver calls it.
  Finder toggle(String name) => find.bySemanticsLabel('$name line');

  group('states', () {
    testWidgets('shows a spinner until the trends arrive', (tester) async {
      final trends = StreamController<Trends>.broadcast();
      addTearDown(trends.close);
      when(() => watchTrends(any())).thenAnswer((_) => trends.stream);

      await pumpTrends(tester);

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('explains the feature until a check-in is rated', (
      tester,
    ) async {
      stubCheckIns([ago(1), ago(2)]);

      await pumpTrends(tester);

      expect(find.text('No ratings yet'), findsOneWidget);
      expect(find.textContaining('Rate your effort and energy'), findsOne);
      expect(find.byType(LineChart), findsNothing);
      expect(
        find.byType(CupertinoSlidingSegmentedControl<TrendRange>),
        findsNothing,
      );
    });

    testWidgets('a failure offers to try again, which reloads', (tester) async {
      var attempts = 0;
      when(() => watchTrends(any())).thenAnswer(
        (_) => attempts++ == 0
            ? Stream.error(const StorageFailure())
            : Stream.value(
                Trends.from(rated, range: TrendRange.month, today: today),
              ),
      );
      await pumpTrends(tester);
      expect(find.text("Couldn't load your trends"), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
    });
  });

  group('content', () {
    testWidgets("summarises the past month's effort and energy", (
      tester,
    ) async {
      await pumpTrends(tester);

      expect(find.byType(LineChart), findsOneWidget);
      expect(
        find.text('Effort averaged 70%, up from 40% the month before.'),
        findsOneWidget,
      );
      expect(find.text('Energy averaged 50%.'), findsOneWidget);
    });

    testWidgets('another range shows its own trends', (tester) async {
      await pumpTrends(tester);

      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();

      verify(() => watchTrends(TrendRange.year)).called(1);
      // The month before no longer counts as before: it's in the year.
      expect(find.text('Effort averaged 60%.'), findsOneWidget);
    });

    testWidgets('a range without ratings says so, in place of the chart', (
      tester,
    ) async {
      stubCheckIns([ago(200, effort: Rating.low)]);

      await pumpTrends(tester);

      expect(find.text('No ratings in the past month'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('No effort ratings in the past month.'), findsOneWidget);
    });
  });

  group('chart', () {
    testWidgets('draws effort solid in green and energy dashed in blue', (
      tester,
    ) async {
      await pumpTrends(tester);

      List<double> percentsOf(LineChartBarData bar) => [
        for (final spot in bar.spots)
          if (!spot.isNull()) spot.y,
      ];

      final [effort, energy] = bars(tester);
      expect(effort.color, colors.chartEffort);
      expect(effort.dashArray, isNull);
      expect(percentsOf(effort), [60, 80]);
      expect(energy.color, colors.chartEnergy);
      expect(energy.dashArray, isNotNull);
      expect(percentsOf(energy), [40, 60]);
    });

    testWidgets('places points by day, and breaks the line across a gap', (
      tester,
    ) async {
      // 10 and 2 days ago are 8 days apart, more than a week.
      await pumpTrends(tester);

      final effort = bars(tester).first;
      expect(effort.spots, [
        const FlSpot(19, 60),
        FlSpot.nullSpot,
        const FlSpot(27, 80),
      ]);
    });

    testWidgets('a toggle hides its line and shows it again', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTrends(tester);

      await tester.tap(toggle('Effort'));
      await tester.pumpAndSettle();

      expect(bars(tester).map((bar) => bar.color), [colors.chartEnergy]);
      expect(
        tester.getSemantics(toggle('Effort')),
        isSemantics(isButton: true, isToggled: false, hasTapAction: true),
      );

      await tester.tap(toggle('Effort'));
      await tester.pumpAndSettle();

      expect(bars(tester), hasLength(2));
      expect(
        tester.getSemantics(toggle('Effort')),
        isSemantics(isButton: true, isToggled: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('the last line showing stays', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTrends(tester);

      await tester.tap(toggle('Energy'));
      await tester.pumpAndSettle();
      await tester.tap(toggle('Effort'));
      await tester.pumpAndSettle();

      expect(bars(tester).map((bar) => bar.color), [colors.chartEffort]);
      semantics.dispose();
    });

    testWidgets('a toggle gives a light haptic tap', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTrends(tester);
      haptics.clear();

      await tester.tap(toggle('Energy'));
      await tester.pumpAndSettle();

      expect(haptics, ['HapticFeedbackType.selectionClick']);
      semantics.dispose();
    });
  });

  group('accessibility', () {
    testWidgets('VoiceOver reads the chart as its summary, in one stop', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTrends(tester);

      expect(
        find.bySemanticsLabel(
          'Effort and energy over the past month. Effort averaged 70%, up '
          'from 40% the month before. Energy averaged 50%.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('the ranges are a choice, with the current one selected', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTrends(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Month')),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('3 Months')),
        isSemantics(
          isButton: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('every control has a label and a comfortable target', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTrends(tester);

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('text has enough contrast', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTrends(tester);

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });

    testWidgets('a hidden line has enough contrast too', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTrends(tester);
      await tester.tap(toggle('Energy'));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });

  testWidgets('Back returns to the previous screen', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTrends(tester);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    semantics.dispose();
  });

  for (final (name, screen) in [
    ('', phoneScreen),
    (' on the smallest iPhone', smallestPhoneScreen),
  ]) {
    group('at 3x text size$name', () {
      Future<void> expectFits(WidgetTester tester) async {
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      testWidgets('the chart and its summary fit', (tester) async {
        await pumpTrends(tester, textScale: 3, screen: screen);

        await expectFits(tester);
      });

      testWidgets('the year fits', (tester) async {
        await pumpTrends(tester, textScale: 3, screen: screen);
        await tester.tap(find.text('Year'));
        await tester.pumpAndSettle();

        await expectFits(tester);
      });

      testWidgets('the explanation fits', (tester) async {
        stubCheckIns(const []);
        await pumpTrends(tester, textScale: 3, screen: screen);

        await expectFits(tester);
      });
    });
  }
}
