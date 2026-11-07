import 'package:flutter/material.dart';

import 'app.dart';
import 'di.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Sets the app up and returns what to show.
///
/// Everything here runs before the first frame, so without this an error
/// would leave the user on the launch screen forever, with an app that looks
/// frozen. Whatever goes wrong, they get a message and a way to try again
/// instead, which is why this catches errors of every kind.
Future<Widget> buildApp({
  Future<void> Function() configure = configureDependencies,
}) async {
  try {
    await configure();
    return GymGridApp(router: createRouter());
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'gym_grid',
        context: ErrorDescription('while starting the app'),
      ),
    );

    return StartupFailureApp(
      onRetry: () async {
        // Anything registered before the failure would clash the second time.
        await getIt.reset();
        runApp(await buildApp(configure: configure));
      },
    );
  }
}

/// Shown in place of the app when it couldn't start.
class StartupFailureApp extends StatefulWidget {
  const StartupFailureApp({required this.onRetry, super.key});

  /// Tries to start again, replacing this widget if that works.
  final Future<void> Function() onRetry;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    await widget.onRetry();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymGrid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Builder(
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.xs,
                  children: [
                    Text(
                      "GymGrid couldn't start",
                      textAlign: TextAlign.center,
                      style: context.textStyles.bodyStrong.copyWith(
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Try again. If this keeps happening, restart your '
                      'phone.',
                      textAlign: TextAlign.center,
                      style: context.textStyles.footnote.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _isRetrying ? null : _retry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
