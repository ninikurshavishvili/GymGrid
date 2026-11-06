import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/check_in/presentation/check_in_cubit.dart';
import '../features/check_in/presentation/check_in_screen.dart';
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

  /// Location of the detail screen for [day], e.g. `/day/2026-10-03`.
  static String dayDetail(DateTime day) => '/day/${_formatDay(day)}';

  static String _formatDay(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  /// Parses a `yyyy-MM-dd` path segment. Anything else, including valid
  /// date-times like `2026-10-03T10:00`, returns null.
  static DateTime? _parseDay(String? raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || _formatDay(parsed) != raw) return null;
    return parsed;
  }
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
            // A modal, like an iOS compose sheet: this is a task to finish
            // or cancel, not a place to go.
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              fullscreenDialog: true,
              child: BlocProvider(
                create: (_) {
                  final cubit = CheckInCubit(
                    saveCheckIn: getIt(),
                    getCheckIn: getIt(),
                    photoPicker: getIt(),
                    clock: getIt(),
                  );
                  unawaited(cubit.load());
                  return cubit;
                },
                child: const CheckInScreen(),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes._dayDetailSegment,
            builder: (context, state) {
              final day = AppRoutes._parseDay(
                state.pathParameters[AppRoutes._dayParam],
              );
              if (day == null) return const _NotFoundScreen();
              return DayDetailScreen(day: day);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
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
