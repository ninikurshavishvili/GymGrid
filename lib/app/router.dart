import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/date/calendar_day.dart';
import '../features/check_in/presentation/check_in_cubit.dart';
import '../features/check_in/presentation/check_in_screen.dart';
import '../features/progress/presentation/day_detail_cubit.dart';
import '../features/progress/presentation/day_detail_screen.dart';
import '../features/progress/presentation/history_cubit.dart';
import '../features/progress/presentation/history_screen.dart';
import '../features/progress/presentation/home_cubit.dart';
import '../features/progress/presentation/home_screen.dart';
import '../features/progress/presentation/trends_cubit.dart';
import '../features/progress/presentation/trends_screen.dart';
import '../features/settings/presentation/settings_cubit.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_links.dart';
import 'di.dart';

/// Route locations. Screens navigate through these helpers rather than
/// building path strings themselves.
abstract final class AppRoutes {
  static const String home = '/';

  static const String _checkInSegment = 'check-in';
  static const String checkIn = '/$_checkInSegment';

  static const String _historySegment = 'history';
  static const String history = '/$_historySegment';

  static const String _settingsSegment = 'settings';
  static const String settings = '/$_settingsSegment';

  static const String _trendsSegment = 'trends';
  static const String trends = '/$_trendsSegment';

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
/// Check-in, history, settings, trends and day detail are children of home,
/// so a deep link to `/day/2026-10-03` still has home underneath it to go
/// back to. A day opened from history is pushed on top of it instead, so
/// Back returns there.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => BlocProvider(
          // BlocProvider owns the Cubit and closes it with the screen, like
          // a SwiftUI `@StateObject`.
          create: (_) =>
              HomeCubit(watchProgress: getIt(), clock: getIt())..watch(),
          child: HomeScreen(photoLocator: getIt()),
        ),
        routes: [
          GoRoute(
            path: AppRoutes._checkInSegment,
            pageBuilder: (context, state) => _checkInPage(state),
          ),
          GoRoute(
            path: AppRoutes._historySegment,
            builder: (context, state) => BlocProvider(
              create: (_) => HistoryCubit(watchHistory: getIt())..watch(),
              child: HistoryScreen(photoLocator: getIt()),
            ),
          ),
          GoRoute(
            path: AppRoutes._trendsSegment,
            builder: (context, state) => BlocProvider(
              create: (_) => TrendsCubit(watchTrends: getIt())..watch(),
              child: const TrendsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes._settingsSegment,
            builder: (context, state) => BlocProvider(
              create: (_) => SettingsCubit(
                deleteAllCheckIns: getIt(),
                linkOpener: getIt(),
              ),
              child: SettingsScreen(
                version: _versionOf(getIt<PackageInfo>()),
                privacyPolicy: Uri.parse(AppLinks.privacyPolicy),
              ),
            ),
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

/// The version as the App Store shows it, with the build in brackets:
/// "1.0.0 (1)".
String _versionOf(PackageInfo info) => '${info.version} (${info.buildNumber})';

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
