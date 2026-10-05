import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';

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
      // Screens without an AppBar (such as home) still need light status bar
      // icons on the dark background. AppBars override this with the same
      // style from the theme.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemOverlayStyle,
        child: child!,
      ),
    );
  }
}
