import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/date/clock.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/core/widgets/primary_button.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/usecases/get_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/save_check_in.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_cubit.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_screen.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_themed.dart';

class _MockSaveCheckIn extends Mock implements SaveCheckIn {}

class _MockGetCheckIn extends Mock implements GetCheckIn {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

void main() {
  late _MockSaveCheckIn saveCheckIn;
  late _MockGetCheckIn getCheckIn;
  late _MockPhotoPicker photoPicker;

  final today = CalendarDay(2026, 11, 6);
  final stored = CheckIn(
    id: '1',
    date: today,
    photoPath: 'photos/1.jpg',
    workoutType: WorkoutType.strength,
    createdAt: DateTime(2026, 11, 6, 7, 42),
  );

  setUpAll(() {
    registerFallbackValue(WorkoutType.other);
    registerFallbackValue(today);
  });

  setUp(() {
    saveCheckIn = _MockSaveCheckIn();
    getCheckIn = _MockGetCheckIn();
    photoPicker = _MockPhotoPicker();
    when(() => getCheckIn(any())).thenAnswer((_) async => null);
    when(
      () => photoPicker.takePhoto(),
    ).thenAnswer((_) async => '/no/such/camera.jpg');
  });

  void stubSave(Future<CheckIn> Function() answer) {
    when(
      () => saveCheckIn(
        sourcePhotoPath: any(named: 'sourcePhotoPath'),
        workoutType: any(named: 'workoutType'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) => answer());
  }

  /// Pumps a stand-in home screen with the check-in screen open on top, so
  /// leaving it has somewhere to go.
  Future<void> pumpCheckIn(WidgetTester tester, {double textScale = 1}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('home screen'),
          routes: [
            GoRoute(
              path: 'check-in',
              builder: (context, state) => BlocProvider(
                create: (_) {
                  final cubit = CheckInCubit(
                    saveCheckIn: saveCheckIn,
                    getCheckIn: getCheckIn,
                    photoPicker: photoPicker,
                    clock: Clock(() => DateTime(2026, 11, 6, 20)),
                  );
                  unawaited(cubit.load());
                  return cubit;
                },
                child: const CheckInScreen(),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScreen(tester, router, textScale: textScale);
    unawaited(router.push('/check-in'));
    await tester.pumpAndSettle();
  }

  Future<void> takePhoto(WidgetTester tester) async {
    await tester.tap(find.text("Tap to take today's photo"));
    await tester.pumpAndSettle();
  }

  Future<void> chooseWorkout(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  VoidCallback? saveButton(WidgetTester tester) =>
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed;

  group('form', () {
    testWidgets('starts empty, with Save disabled', (tester) async {
      await pumpCheckIn(tester);

      expect(find.text('Check in'), findsOneWidget);
      expect(find.text("Tap to take today's photo"), findsOneWidget);
      expect(find.text('Choose from library'), findsOneWidget);
      for (final label in ['Strength', 'Cardio', 'Mobility', 'Other']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Note (optional)'), findsOneWidget);
      expect(saveButton(tester), isNull);
    });

    testWidgets('a workout type alone does not enable Save', (tester) async {
      await pumpCheckIn(tester);

      await chooseWorkout(tester, 'Cardio');

      expect(saveButton(tester), isNull);
    });

    testWidgets('a photo alone does not enable Save', (tester) async {
      await pumpCheckIn(tester);

      await takePhoto(tester);

      expect(saveButton(tester), isNull);
    });

    testWidgets('a photo and a workout type enable Save', (tester) async {
      await pumpCheckIn(tester);

      await takePhoto(tester);
      await chooseWorkout(tester, 'Cardio');

      expect(saveButton(tester), isNotNull);
    });

    testWidgets('a taken photo can be retaken', (tester) async {
      await pumpCheckIn(tester);

      await takePhoto(tester);

      expect(find.text("Tap to take today's photo"), findsNothing);
      expect(find.text('Retake'), findsOneWidget);
    });

    testWidgets('shows progress while a picked photo is prepared', (
      tester,
    ) async {
      final picking = Completer<String?>();
      when(() => photoPicker.takePhoto()).thenAnswer((_) => picking.future);
      await pumpCheckIn(tester);

      await tester.tap(find.text("Tap to take today's photo"));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      picking.complete('/no/such/camera.jpg');
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.text('Retake'), findsOneWidget);
    });

    testWidgets('counts the note against the limit', (tester) async {
      await pumpCheckIn(tester);

      await tester.enterText(find.byType(TextField), 'Leg day');
      await tester.pump();

      expect(find.text('7/${CheckIn.maxNoteLength}'), findsOneWidget);
    });

    testWidgets('stops the note at the limit', (tester) async {
      await pumpCheckIn(tester);

      await tester.enterText(find.byType(TextField), 'a' * 300);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, hasLength(CheckIn.maxNoteLength));
    });

    testWidgets('warns when saving would replace today', (tester) async {
      when(() => getCheckIn(any())).thenAnswer((_) async => stored);

      await pumpCheckIn(tester);

      expect(find.text("This replaces today's check-in."), findsOneWidget);
    });

    testWidgets('does not warn when today is free', (tester) async {
      await pumpCheckIn(tester);

      expect(find.text("This replaces today's check-in."), findsNothing);
    });
  });

  group('camera access off', () {
    setUp(() {
      when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => throw const PhotoUnavailable('denied'));
    });

    testWidgets('explains and offers Settings', (tester) async {
      when(() => photoPicker.openSettings()).thenAnswer((_) async {});
      await pumpCheckIn(tester);

      await takePhoto(tester);

      expect(find.textContaining('Camera access is off'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      verify(() => photoPicker.openSettings()).called(1);
    });

    testWidgets('the library still works, and clears the message', (
      tester,
    ) async {
      when(
        () => photoPicker.pickFromLibrary(),
      ).thenAnswer((_) async => '/no/such/library.jpg');
      await pumpCheckIn(tester);
      await takePhoto(tester);

      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Camera access is off'), findsNothing);
      expect(find.text('Retake'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('closes the screen and gives a haptic tap on success', (
      tester,
    ) async {
      final haptics = <String?>[];
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
      stubSave(() async => stored);
      await pumpCheckIn(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Strength');
      await tester.enterText(find.byType(TextField), 'Deadlift PR');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        () => saveCheckIn(
          sourcePhotoPath: '/no/such/camera.jpg',
          workoutType: WorkoutType.strength,
          note: 'Deadlift PR',
        ),
      ).called(1);
      expect(find.byType(CheckInScreen), findsNothing);
      expect(find.text('home screen'), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
    });

    testWidgets('shows a spinner while saving', (tester) async {
      final saving = Completer<CheckIn>();
      stubSave(() => saving.future);
      await pumpCheckIn(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Strength');

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      saving.complete(stored);
      await tester.pumpAndSettle();
    });

    testWidgets('a failure shows an error, keeps the form and can retry', (
      tester,
    ) async {
      stubSave(() async => throw const StorageFailure());
      await pumpCheckIn(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Strength');
      await tester.enterText(find.byType(TextField), 'Deadlift PR');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't save your check-in. Try again."),
        findsOneWidget,
      );
      expect(find.byType(CheckInScreen), findsOneWidget);
      expect(find.text('Deadlift PR'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);

      stubSave(() async => stored);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
    });
  });

  group('leaving', () {
    testWidgets('an untouched form closes straight away', (tester) async {
      await pumpCheckIn(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this check-in?'), findsNothing);
      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('choosing only a workout type closes straight away', (
      tester,
    ) async {
      await pumpCheckIn(tester);
      await chooseWorkout(tester, 'Cardio');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('with a photo, asks first, and can keep editing', (
      tester,
    ) async {
      await pumpCheckIn(tester);
      await takePhoto(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this check-in?'), findsOneWidget);

      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this check-in?'), findsNothing);
      expect(find.text('Retake'), findsOneWidget);
    });

    testWidgets('with a photo, Discard closes the screen', (tester) async {
      await pumpCheckIn(tester);
      await takePhoto(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(CheckInScreen), findsNothing);
      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('a typed note also asks first', (tester) async {
      await pumpCheckIn(tester);
      await tester.enterText(find.byType(TextField), 'Leg day');
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this check-in?'), findsOneWidget);
    });

    testWidgets('Cancel is disabled while saving', (tester) async {
      final saving = Completer<CheckIn>();
      stubSave(() => saving.future);
      await pumpCheckIn(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Strength');

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Cancel'), warnIfMissed: false);
      await tester.pump();

      expect(find.text('Discard this check-in?'), findsNothing);

      saving.complete(stored);
      await tester.pumpAndSettle();
    });
  });

  group('at 3x text size', () {
    Future<void> scrollToBottom(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
    }

    testWidgets('an empty form fits', (tester) async {
      await pumpCheckIn(tester, textScale: 3);
      expect(tester.takeException(), isNull);

      await scrollToBottom(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a form with every message showing fits', (tester) async {
      when(() => getCheckIn(any())).thenAnswer((_) async => stored);
      when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => throw const PhotoUnavailable('denied'));
      when(
        () => photoPicker.pickFromLibrary(),
      ).thenAnswer((_) async => '/no/such/library.jpg');
      stubSave(() async => throw const StorageFailure());
      await pumpCheckIn(tester, textScale: 3);

      await takePhoto(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Strength'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('Strength'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await scrollToBottom(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the discard question fits', (tester) async {
      await pumpCheckIn(tester, textScale: 3);
      await takePhoto(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
