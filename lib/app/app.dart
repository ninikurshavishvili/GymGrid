import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

class GymGridApp extends StatelessWidget {
  const GymGridApp({required this.router, super.key});

  /// Created once in `main` so rebuilding this widget never resets the
  /// navigation stack.
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GymGrid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
