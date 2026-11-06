import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/date/calendar_day.dart';
import '../features/check_in/presentation/check_in_cubit.dart';
import '../features/check_in/presentation/check_in_screen.dart';
import '../features/progress/presentation/day_detail_cubit.dart';
import '../features/progress/presentation/day_detail_screen.dart';
import '../features/progress/presentation/home_cubit.dart';
import '../features/progress/presentation/home_screen.dart';
import 'di.dart';

/// Route locations. Screens navigate through these helpers rather than
/// building path strings themselves.
abstract final class AppRoutes {
  static const String home = '/';

  static const String _checkInSegment = 'check-in';
  static const String checkIn = '/$_checkInSegment';

  static const String _dayParam = 'date';
  static const String _dayDetailSegment = 'day/:$_dayParam';
  static const String _editSegment = 'edit';

  /// Location of the detail screen for [day], e.g. `/day/2026-10-03`.
  static String dayDetail(CalendarDay day) => '/day/${day.toIso8601String()}';

  /// Location of the form that edits [day]'s check-in.
  static String editDay(CalendarDay day) => '${dayDetail(day)}/$_editSegment';

  static CalendarDay? _dayOf(GoRouterState state) =>
      CalendarDay.tryParse(state.pathParameters[_dayParam] ?? '');
}

/// Builds the app's route table.
///
/// Check-in and day detail are children of home, so a deep link to
/// `/day/2026-10-03` still has home underneath it to go back to.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => BlocProvider(
          // BlocProvider owns the Cubit and closes it with the screen, like
          // a SwiftUI `@StateObject`.
          create: (_) => HomeCubit(watchProgress: getIt())..watch(),
          child: HomeScreen(photoLocator: getIt()),
        ),
        routes: [
          GoRoute(
            path: AppRoutes._checkInSegment,
            pageBuilder: (context, state) => _checkInPage(state),
          ),
          GoRoute(
            path: AppRoutes._dayDetailSegment,
            builder: (context, state) {
              final day = AppRoutes._dayOf(state);
              if (day == null) return const _NotFoundScreen();
              return BlocProvider(
                create: (_) => DayDetailCubit(
                  day: day,
                  watchCheckIn: getIt(),
                  updateCheckIn: getIt(),
                  deleteCheckIn: getIt(),
                  photoPicker: getIt(),
                )..watch(),
                child: DayDetailScreen(day: day, photoLocator: getIt()),
              );
            },
            routes: [
              GoRoute(
                path: AppRoutes._editSegment,
                pageBuilder: (context, state) {
                  final day = AppRoutes._dayOf(state);
                  if (day == null) {
                    return MaterialPage(
                      key: state.pageKey,
                      child: const _NotFoundScreen(),
                    );
                  }
                  return _checkInPage(state, editingDay: day);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
}

/// The check-in form, for today or for editing [editingDay]'s check-in.
///
/// A modal, like an iOS compose sheet: this is a task to finish or cancel,
/// not a place to go.
Page<void> _checkInPage(GoRouterState state, {CalendarDay? editingDay}) {
  return MaterialPage(
    key: state.pageKey,
    fullscreenDialog: true,
    child: BlocProvider(
      create: (_) {
        final cubit = CheckInCubit(
          saveCheckIn: getIt(),
          updateCheckIn: getIt(),
          getCheckIn: getIt(),
          photoPicker: getIt(),
          editingDay: editingDay,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: CheckInScreen(photoLocator: getIt()),
    ),
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('Page not found')),
    );
  }
}
