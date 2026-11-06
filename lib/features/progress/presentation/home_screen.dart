import 'dart:async';

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoIcons,
        CupertinoSliverNavigationBar;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/date/calendar_day.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/streak_card.dart';
import '../../check_in/domain/repositories/photo_locator.dart';
import '../domain/entities/progress.dart';
import '../domain/entities/streak_summary.dart';
import 'home_cubit.dart';
import 'home_state.dart';
import 'widgets/today_card.dart';
import 'widgets/year_activity_card.dart';

/// The app's main screen: streaks, the year so far, and today's check-in.
///
/// Built like an iOS screen rather than a Material one: a large title that
/// collapses on scroll, and a pinned action that's only there while there's
/// something to do. Once the user has checked in the button goes away, and
/// the today row carries the state on its own.
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.photoLocator, super.key});

  final PhotoLocator photoLocator;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final needsCheckIn = switch (state) {
            HomeLoaded(:final progress) => progress.todaysCheckIn == null,
            _ => false,
          };

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    const _NavigationBar(),
                    switch (state) {
                      HomeLoading() => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                      HomeLoaded(:final progress) => _Content(
                        progress: progress,
                        photoLocator: photoLocator,
                        hasBottomBar: needsCheckIn,
                      ),
                      HomeFailure() => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _FailureMessage(),
                      ),
                    },
                  ],
                ),
              ),
              if (needsCheckIn) const _CheckInBar(),
            ],
          );
        },
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar();

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverNavigationBar(
      largeTitle: const Text('GymGrid'),
      // The small title appears only once the large one has scrolled away.
      middle: const Text('GymGrid'),
      alwaysShowMiddle: false,
      backgroundColor: context.colors.bgPrimary,
      border: null,
      // The screens this pushes have Material app bars, which a Cupertino
      // title can't animate into.
      transitionBetweenRoutes: false,
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.progress,
    required this.photoLocator,
    required this.hasBottomBar,
  });

  final Progress progress;
  final PhotoLocator photoLocator;
  final bool hasBottomBar;

  void _openDay(BuildContext context, CalendarDay day) {
    unawaited(context.push(AppRoutes.dayDetail(day.toLocalDateTime())));
  }

  @override
  Widget build(BuildContext context) {
    final today = progress.today;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(today.toLocalDateTime());

    return SliverSafeArea(
      top: false,
      // The bottom bar handles the home indicator when it's showing.
      bottom: !hasBottomBar,
      sliver: SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        sliver: SliverList.list(
          children: [
            Text(
              date,
              style: context.textStyles.footnote.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Streaks(streaks: progress.streaks),
            const SizedBox(height: AppSpacing.md),
            YearActivityCard(
              // A new year is a new grid, starting from its own scroll
              // position.
              key: ValueKey(today.year),
              progress: progress,
              onDayTap: (day) => _openDay(context, day),
            ),
            const SizedBox(height: AppSpacing.md),
            TodayCard(
              progress: progress,
              photoLocator: photoLocator,
              onOpen: () => _openDay(context, today),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two streak counts, side by side until the text gets too large.
class _Streaks extends StatelessWidget {
  const _Streaks({required this.streaks});

  final StreakSummary streaks;

  static const double _gap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final current = StreakCard(
      label: 'Current streak',
      days: streaks.current,
      icon: CupertinoIcons.flame_fill,
      isAtRisk: streaks.isAtRisk,
    );
    final longest = StreakCard(label: 'Longest streak', days: streaks.longest);

    if (context.usesAccessibilityTextSize) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _gap,
        children: [current, longest],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _gap,
        children: [
          Expanded(child: current),
          Expanded(child: longest),
        ],
      ),
    );
  }
}

class _CheckInBar extends StatelessWidget {
  const _CheckInBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: PrimaryButton(
          label: 'Check in',
          icon: CupertinoIcons.camera_fill,
          onPressed: () => context.push(AppRoutes.checkIn),
        ),
      ),
    );
  }
}

class _FailureMessage extends StatelessWidget {
  const _FailureMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            Text(
              "Couldn't load your check-ins",
              textAlign: TextAlign.center,
              style: context.textStyles.bodyStrong.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: context.read<HomeCubit>().watch,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
