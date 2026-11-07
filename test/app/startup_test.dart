import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/app/app.dart';
import 'package:gym_grid/app/di.dart';
import 'package:gym_grid/app/startup.dart';

import '../helpers/pump_themed.dart';

void main() {
  tearDown(() async => getIt.reset());

  /// Runs [body] with Flutter's error reporting silenced, because reporting
  /// the failure is exactly what these tests expect to happen.
  Future<List<FlutterErrorDetails>> capturingErrors(
    Future<void> Function() body,
  ) async {
    final reported = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = reported.add;
    try {
      await body();
    } finally {
      FlutterError.onError = original;
    }
    return reported;
  }

  test('a failure in setup gives the failure screen, and reports it', () async {
    late Widget app;

    final reported = await capturingErrors(() async {
      app = await buildApp(configure: () async => throw StateError('no disk'));
    });

    expect(app, isA<StartupFailureApp>());
    expect(reported.single.exception, isA<StateError>());
  });

  test(
    'an Error from native code is caught too, not only Exceptions',
    () async {
      late Widget app;

      await capturingErrors(() async {
        app = await buildApp(
          configure: () async =>
              throw ArgumentError("Couldn't resolve native function"),
        );
      });

      expect(app, isA<StartupFailureApp>());
    },
  );

  testWidgets('the failure screen says what happened and offers a retry', (
    tester,
  ) async {
    var retries = 0;

    await tester.pumpWidget(StartupFailureApp(onRetry: () async => retries++));

    expect(find.text("GymGrid couldn't start"), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('cannot retry twice at once', (tester) async {
    var retries = 0;
    final retrying = Completer<void>();
    await tester.pumpWidget(
      StartupFailureApp(
        onRetry: () {
          retries++;
          return retrying.future;
        },
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.tap(find.text('Try again'), warnIfMissed: false);
    await tester.pump();

    expect(retries, 1);

    retrying.complete();
    await tester.pump();
  });

  testWidgets('it fits on the smallest iPhone at 3x text size', (tester) async {
    tester.view
      ..physicalSize = smallestPhoneScreen * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: smallestPhoneScreen,
          textScaler: TextScaler.linear(3),
        ),
        child: StartupFailureApp(onRetry: () async {}),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a working setup goes straight to the app', (tester) async {
    late Widget app;

    await capturingErrors(() async {
      app = await buildApp(configure: () async {});
    });

    expect(app, isA<GymGridApp>());
  });
}
