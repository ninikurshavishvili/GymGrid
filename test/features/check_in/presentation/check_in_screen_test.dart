import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/core/widgets/primary_button.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_photo.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/photo_locator.dart';
import 'package:gym_grid/features/check_in/domain/usecases/get_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/save_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/update_check_in.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_cubit.dart';
import 'package:gym_grid/features/check_in/presentation/check_in_screen.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:gym_grid/features/check_in/presentation/widgets/photo_strip.dart';
import 'package:gym_grid/features/check_in/presentation/widgets/rating_picker.dart';
import 'package:gym_grid/features/check_in/presentation/workout_type_labels.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_themed.dart';

class _MockSaveCheckIn extends Mock implements SaveCheckIn {}

class _MockUpdateCheckIn extends Mock implements UpdateCheckIn {}

class _MockGetCheckIn extends Mock implements GetCheckIn {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

class _FakePhotoLocator implements PhotoLocator {
  const _FakePhotoLocator();

  @override
  Uri uriOf(String photoPath) => Uri.file('/no/such/folder/$photoPath');
}

void main() {
  late _MockSaveCheckIn saveCheckIn;
  late _MockUpdateCheckIn updateCheckIn;
  late _MockGetCheckIn getCheckIn;
  late _MockPhotoPicker photoPicker;
  late List<String?> haptics;

  final today = CalendarDay(2026, 11, 6);
  final stored = CheckIn(
    id: '1',
    date: today,
    photoPaths: const ['photos/1.jpg', 'photos/2.jpg'],
    workoutType: WorkoutType.cardio,
    note: 'Intervals',
    createdAt: DateTime(2026, 11, 6, 7, 42),
  );

  setUpAll(() {
    registerFallbackValue(WorkoutType.other);
    registerFallbackValue(OtherActivity.sport);
    registerFallbackValue(Rating.medium);
    registerFallbackValue(today);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<CheckInPhoto>[]);
  });

  setUp(() {
    saveCheckIn = _MockSaveCheckIn();
    updateCheckIn = _MockUpdateCheckIn();
    getCheckIn = _MockGetCheckIn();
    photoPicker = _MockPhotoPicker();
    when(() => photoPicker.discard(any())).thenAnswer((_) async {});
    haptics = [];
    when(() => getCheckIn(any())).thenAnswer((_) async => stored);
    when(
      () => photoPicker.takePhoto(),
    ).thenAnswer((_) async => '/no/such/camera.jpg');
    when(
      () => photoPicker.pickFromLibrary(),
    ).thenAnswer((_) async => '/no/such/library.jpg');
  });

  void stubSave(Future<CheckIn> Function() answer) {
    when(
      () => saveCheckIn(
        sourcePhotoPaths: any(named: 'sourcePhotoPaths'),
        workoutType: any(named: 'workoutType'),
        activity: any(named: 'activity'),
        note: any(named: 'note'),
        effort: any(named: 'effort'),
        energy: any(named: 'energy'),
      ),
    ).thenAnswer((_) => answer());
  }

  void stubUpdate(Future<CheckIn> Function() answer) {
    when(
      () => updateCheckIn(
        id: any(named: 'id'),
        photos: any(named: 'photos'),
        workoutType: any(named: 'workoutType'),
        activity: any(named: 'activity'),
        effort: any(named: 'effort'),
        energy: any(named: 'energy'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) => answer());
  }

  /// Pumps a stand-in previous screen with the form open on top, so leaving
  /// it has somewhere to go.
  Future<void> pumpForm(
    WidgetTester tester, {
    CalendarDay? editingDay,
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
          path: '/',
          builder: (context, state) => const Text('previous screen'),
          routes: [
            GoRoute(
              path: 'form',
              builder: (context, state) => BlocProvider(
                create: (_) {
                  final cubit = CheckInCubit(
                    saveCheckIn: saveCheckIn,
                    updateCheckIn: updateCheckIn,
                    getCheckIn: getCheckIn,
                    photoPicker: photoPicker,
                    editingDay: editingDay,
                  );
                  unawaited(cubit.load());
                  return cubit;
                },
                child: const CheckInScreen(photoLocator: _FakePhotoLocator()),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScreen(tester, router, textScale: textScale, screen: screen);
    unawaited(router.push('/form'));
    await tester.pumpAndSettle();
  }

  Future<void> takePhoto(WidgetTester tester) async {
    await tester.tap(find.text("Tap to take today's photo"));
    await tester.pumpAndSettle();
  }

  Future<void> chooseWorkout(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Scrolls the pill for [label] into view, which is below the fold on a
  /// phone, and taps it.
  Future<void> chooseActivity(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// The pill for [step] in the [title] row, such as Effort's "80%".
  Finder ratingPill(String title, String step) => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is RatingPicker && widget.title == title,
    ),
    matching: find.text(step),
  );

  /// Scrolls the pill into view, which is below the fold on a phone, and
  /// taps it.
  Future<void> rate(WidgetTester tester, String title, String step) async {
    final pill = ratingPill(title, step);
    await tester.ensureVisible(pill);
    await tester.pumpAndSettle();
    await tester.tap(pill);
    await tester.pumpAndSettle();
  }

  PrimaryButton button(WidgetTester tester) =>
      tester.widget<PrimaryButton>(find.byType(PrimaryButton));

  group('button', () {
    testWidgets('asks for a photo first', (tester) async {
      await pumpForm(tester);

      expect(button(tester).label, 'Add a photo to continue');
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('then asks for a workout', (tester) async {
      await pumpForm(tester);

      await takePhoto(tester);

      expect(button(tester).label, 'Choose a workout');
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('a workout alone still asks for a photo', (tester) async {
      await pumpForm(tester);

      await chooseWorkout(tester, 'Cardio');

      expect(button(tester).label, 'Add a photo to continue');
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('offers to save once both are there', (tester) async {
      await pumpForm(tester);

      await takePhoto(tester);
      await chooseWorkout(tester, 'Cardio');

      expect(button(tester).label, 'Save check-in');
      expect(button(tester).onPressed, isNotNull);
    });
  });

  group('workout type', () {
    testWidgets('offers every type', (tester) async {
      await pumpForm(tester);

      for (final type in WorkoutType.values) {
        expect(find.text(type.label), findsOneWidget);
        expect(find.byIcon(type.icon), findsOneWidget);
      }
    });

    testWidgets('choosing one gives a light haptic tap', (tester) async {
      await pumpForm(tester);

      await chooseWorkout(tester, 'Strength');

      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('announces the chosen type as selected', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);

      await chooseWorkout(tester, 'Mobility');

      expect(
        tester.getSemantics(find.bySemanticsLabel('Mobility')),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Cardio')),
        isSemantics(isButton: true, isSelected: false, hasTapAction: true),
      );
      semantics.dispose();
    });
  });

  group('VoiceOver can activate', () {
    testWidgets('a suggestion', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);
      await chooseWorkout(tester, 'Strength');

      expect(
        tester.getSemantics(find.bySemanticsLabel('Add Legs to the note')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('adding and removing a photo', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);
      await takePhoto(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Add a photo')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Remove photo 1 of 1')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });
  });

  group('note', () {
    testWidgets('its prompt follows the workout type', (tester) async {
      await pumpForm(tester);
      expect(find.text('Add a note (optional)'), findsOneWidget);

      await chooseWorkout(tester, 'Strength');
      expect(find.text(WorkoutType.strength.notePrompt), findsOneWidget);

      await chooseWorkout(tester, 'Cardio');
      expect(find.text(WorkoutType.cardio.notePrompt), findsOneWidget);
      expect(find.text(WorkoutType.strength.notePrompt), findsNothing);
    });

    testWidgets('suggestions appear with the workout type and change with it', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(find.text('Legs'), findsNothing);

      await chooseWorkout(tester, 'Strength');
      expect(find.text('Legs'), findsOneWidget);

      await chooseWorkout(tester, 'Cardio');
      expect(find.text('Legs'), findsNothing);
      expect(find.text('Intervals'), findsOneWidget);
    });

    testWidgets('a suggestion goes into the note and leaves the list', (
      tester,
    ) async {
      await pumpForm(tester);
      await chooseWorkout(tester, 'Strength');

      await tester.tap(find.text('Legs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PR'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Legs, PR');
      expect(find.text('Push'), findsOneWidget);
    });

    testWidgets('a suggestion joins what was already typed', (tester) async {
      await pumpForm(tester);
      await chooseWorkout(tester, 'Strength');
      await tester.enterText(find.byType(TextField), 'Felt strong');
      await tester.pump();

      // Below the ratings, so off screen on a phone.
      await tester.ensureVisible(find.text('Legs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Legs'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Felt strong, Legs');
    });

    testWidgets('a suggestion that would pass the limit is left out', (
      tester,
    ) async {
      await pumpForm(tester);
      await chooseWorkout(tester, 'Strength');
      await tester.enterText(
        find.byType(TextField),
        'a' * CheckIn.maxNoteLength,
      );
      await tester.pump();

      await tester.tap(find.text('Legs'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, hasLength(CheckIn.maxNoteLength));
    });

    testWidgets('counts against the limit once there is text', (tester) async {
      await pumpForm(tester);
      expect(find.textContaining('/${CheckIn.maxNoteLength}'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Leg day');
      await tester.pump();

      expect(find.text('7/${CheckIn.maxNoteLength}'), findsOneWidget);
    });

    testWidgets('stops at the limit', (tester) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField), 'a' * 300);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, hasLength(CheckIn.maxNoteLength));
    });

    // A text field scrolls only its cursor into view, which left the bottom
    // of the field and its count hidden behind the Save bar while typing.
    for (final (name, textScale, screen) in [
      ('', 1.0, phoneScreen),
      (' at 3x text size', 3.0, phoneScreen),
      (' on the smallest iPhone', 1.0, smallestPhoneScreen),
    ]) {
      testWidgets('stays above the Save bar while typing with the keyboard '
          'up$name', (tester) async {
        await pumpForm(
          tester,
          editingDay: today,
          textScale: textScale,
          screen: screen,
        );
        // Scrolls only until the field shows, near the bottom, as when the
        // user reaches it.
        await tester.dragUntilVisible(
          find.byType(TextField),
          find.byType(ListView).first,
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextField));
        // An iPhone keyboard with its suggestion bar, at the view's three
        // pixels per point.
        tester.view.viewInsets = const FakeViewPadding(bottom: 336.0 * 3);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Intervals\nHill sprints\nCool-down walk',
        );
        await tester.pumpAndSettle();

        final visibleBottom = tester
            .getRect(find.byType(ListView).first)
            .bottom;
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(visibleBottom),
        );
        expect(
          tester
              .getRect(find.textContaining('/${CheckIn.maxNoteLength}'))
              .bottom,
          lessThanOrEqualTo(visibleBottom),
        );
      });
    }
  });

  group('Other', () {
    testWidgets('offers activities instead of note suggestions, and only for '
        'Other', (tester) async {
      await pumpForm(tester);

      await chooseWorkout(tester, 'Other');
      for (final activity in OtherActivity.values) {
        expect(find.text(activity.label), findsOneWidget);
      }

      await chooseWorkout(tester, 'Cardio');
      expect(find.text('Sport'), findsNothing);
      expect(find.text('Intervals'), findsOneWidget);
    });

    testWidgets('an activity is a choice, not part of the note', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);
      await chooseWorkout(tester, 'Other');

      await chooseActivity(tester, 'Sport');

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sport')),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Walk')),
        isSemantics(
          isButton: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('tapping the chosen activity again clears it', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);
      await chooseWorkout(tester, 'Other');

      await chooseActivity(tester, 'Walk');
      await chooseActivity(tester, 'Walk');

      expect(
        tester.getSemantics(find.bySemanticsLabel('Walk')),
        isSemantics(
          isButton: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('choosing one gives a light haptic tap', (tester) async {
      await pumpForm(tester);
      await chooseWorkout(tester, 'Other');
      haptics.clear();

      await chooseActivity(tester, 'Class');

      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('saves the chosen activity', (tester) async {
      stubSave(() async => stored);
      await pumpForm(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Other');
      await chooseActivity(tester, 'Class');

      await tester.tap(find.text('Save check-in'));
      await tester.pumpAndSettle();

      verify(
        () => saveCheckIn(
          sourcePhotoPaths: ['/no/such/camera.jpg'],
          workoutType: WorkoutType.other,
          activity: OtherActivity.groupClass,
          note: '',
        ),
      ).called(1);
    });

    testWidgets('an edit opens with the stored activity chosen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      when(() => getCheckIn(any())).thenAnswer(
        (_) async => CheckIn(
          id: '1',
          date: today,
          photoPaths: const ['photos/1.jpg'],
          workoutType: WorkoutType.other,
          activity: OtherActivity.walk,
          createdAt: DateTime(2026, 11, 6, 7, 42),
        ),
      );

      await pumpForm(tester, editingDay: today);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Walk')),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('effort and energy', () {
    testWidgets('each offers five steps under its own heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);
      await tester.ensureVisible(ratingPill('Energy', '100%'));
      await tester.pumpAndSettle();

      for (final title in ['Effort', 'Energy']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(title)),
          isSemantics(isHeader: true),
        );
        for (final step in ['20%', '40%', '60%', '80%', '100%']) {
          expect(
            tester.getSemantics(find.bySemanticsLabel('$title $step')),
            isSemantics(
              isButton: true,
              isSelected: false,
              isInMutuallyExclusiveGroup: true,
              hasTapAction: true,
            ),
          );
        }
      }
      semantics.dispose();
    });

    testWidgets('a step is a choice, and tapping it again clears it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);

      await rate(tester, 'Effort', '80%');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Effort 80%')),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Energy 80%')),
        isSemantics(
          isButton: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );

      await rate(tester, 'Effort', '80%');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Effort 80%')),
        isSemantics(
          isButton: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('choosing one gives a light haptic tap', (tester) async {
      await pumpForm(tester);
      haptics.clear();

      await rate(tester, 'Energy', '60%');

      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('saves the chosen ratings', (tester) async {
      stubSave(() async => stored);
      await pumpForm(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Strength');
      await rate(tester, 'Effort', '80%');
      await rate(tester, 'Energy', '40%');

      await tester.tap(find.text('Save check-in'));
      await tester.pumpAndSettle();

      verify(
        () => saveCheckIn(
          sourcePhotoPaths: ['/no/such/camera.jpg'],
          workoutType: WorkoutType.strength,
          note: '',
          effort: Rating.high,
          energy: Rating.low,
        ),
      ).called(1);
    });

    testWidgets('an edit opens with the stored ratings chosen, and changing '
        'one can be saved', (tester) async {
      final semantics = tester.ensureSemantics();
      stubUpdate(() async => stored);
      when(() => getCheckIn(any())).thenAnswer(
        (_) async => CheckIn(
          id: '1',
          date: today,
          photoPaths: const ['photos/1.jpg'],
          workoutType: WorkoutType.cardio,
          effort: Rating.max,
          energy: Rating.medium,
          createdAt: DateTime(2026, 11, 6, 7, 42),
        ),
      );
      await pumpForm(tester, editingDay: today);
      await tester.ensureVisible(ratingPill('Energy', '60%'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Effort 100%')),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Energy 60%')),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(button(tester).onPressed, isNull);

      await rate(tester, 'Energy', '60%');
      expect(button(tester).onPressed, isNotNull);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      verify(
        () => updateCheckIn(
          id: '1',
          photos: const [StoredPhoto('photos/1.jpg')],
          workoutType: WorkoutType.cardio,
          activity: null,
          effort: Rating.max,
          energy: null,
          note: '',
        ),
      ).called(1);
      semantics.dispose();
    });

    testWidgets('choosing only a rating closes straight away', (tester) async {
      await pumpForm(tester);
      await rate(tester, 'Effort', '20%');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('previous screen'), findsOneWidget);
    });
  });

  group('photos', () {
    Future<void> addAnother(WidgetTester tester, String source) async {
      await tester.tap(find.byIcon(CupertinoIcons.plus));
      await tester.pumpAndSettle();
      await tester.tap(find.text(source));
      await tester.pumpAndSettle();
    }

    testWidgets('the first photo swaps the big frame for the strip', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(find.byType(PhotoStrip), findsNothing);

      await takePhoto(tester);

      expect(find.text("Tap to take today's photo"), findsNothing);
      expect(find.byType(PhotoStrip), findsOneWidget);
    });

    testWidgets('can choose the first photo from the library', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoStrip), findsOneWidget);
    });

    testWidgets('another can come from the camera or the library', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);
      await takePhoto(tester);

      await addAnother(tester, 'Choose from Library');
      await addAnother(tester, 'Take Photo');

      expect(find.bySemanticsLabel('Photo 3 of 3'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('cancelling the sheet adds nothing', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);
      await takePhoto(tester);

      await tester.tap(find.byIcon(CupertinoIcons.plus));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Photo 1 of 1'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('removing the only photo brings the big frame back', (
      tester,
    ) async {
      await pumpForm(tester);
      await takePhoto(tester);

      await tester.tap(find.byIcon(CupertinoIcons.xmark));
      await tester.pumpAndSettle();

      expect(find.text("Tap to take today's photo"), findsOneWidget);
      expect(button(tester).label, 'Add a photo to continue');
    });

    testWidgets('stops offering to add at the limit', (tester) async {
      await pumpForm(tester);
      await takePhoto(tester);

      for (var count = 1; count < CheckIn.maxPhotos; count++) {
        await tester.drag(find.byType(PhotoStrip), const Offset(-2000, 0));
        await tester.pumpAndSettle();
        await addAnother(tester, 'Take Photo');
      }
      await tester.drag(find.byType(PhotoStrip), const Offset(-2000, 0));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.plus), findsNothing);
    });

    testWidgets('shows progress while a picked photo is prepared', (
      tester,
    ) async {
      final picking = Completer<String?>();
      when(() => photoPicker.takePhoto()).thenAnswer((_) => picking.future);
      await pumpForm(tester);

      await tester.tap(find.text("Tap to take today's photo"));
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      picking.complete('/no/such/camera.jpg');
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
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
      await pumpForm(tester);

      await takePhoto(tester);

      expect(find.textContaining('Camera access is off'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      verify(() => photoPicker.openSettings()).called(1);
    });

    testWidgets('the library still works, and clears the message', (
      tester,
    ) async {
      await pumpForm(tester);
      await takePhoto(tester);

      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Camera access is off'), findsNothing);
      expect(find.byType(PhotoStrip), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('closes the screen and gives a firm haptic tap', (
      tester,
    ) async {
      stubSave(() async => stored);
      await pumpForm(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Strength');
      await tester.enterText(find.byType(TextField), 'Deadlift PR');
      await tester.pump();
      haptics.clear();

      await tester.tap(find.text('Save check-in'));
      await tester.pumpAndSettle();

      verify(
        () => saveCheckIn(
          sourcePhotoPaths: ['/no/such/camera.jpg'],
          workoutType: WorkoutType.strength,
          note: 'Deadlift PR',
        ),
      ).called(1);
      expect(find.byType(CheckInScreen), findsNothing);
      expect(find.text('previous screen'), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
    });

    testWidgets('shows a spinner while saving', (tester) async {
      final saving = Completer<CheckIn>();
      stubSave(() => saving.future);
      await pumpForm(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Strength');

      await tester.tap(find.text('Save check-in'));
      await tester.pump();

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      saving.complete(stored);
      await tester.pumpAndSettle();
    });

    testWidgets('a failure shows an error, keeps the form and can retry', (
      tester,
    ) async {
      stubSave(() async => throw const StorageFailure());
      await pumpForm(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Strength');
      await tester.enterText(find.byType(TextField), 'Deadlift PR');
      await tester.pump();

      await tester.tap(find.text('Save check-in'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't save your check-in. Try again."),
        findsOneWidget,
      );
      expect(find.byType(CheckInScreen), findsOneWidget);
      expect(find.text('Deadlift PR'), findsOneWidget);
      expect(find.byType(PhotoStrip), findsOneWidget);

      stubSave(() async => stored);
      await tester.tap(find.text('Save check-in'));
      await tester.pumpAndSettle();

      expect(find.text('previous screen'), findsOneWidget);
    });
  });

  group('editing', () {
    testWidgets('opens filled in with the stored check-in', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester, editingDay: today);

      expect(find.text('Edit check-in'), findsOneWidget);
      expect(find.bySemanticsLabel('Photo 1 of 2'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Intervals');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Cardio')),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('has nothing to save until something changes', (tester) async {
      await pumpForm(tester, editingDay: today);

      expect(button(tester).label, 'Save changes');
      expect(button(tester).onPressed, isNull);

      await chooseWorkout(tester, 'Strength');

      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('saves the changes and closes', (tester) async {
      stubUpdate(() async => stored);
      await pumpForm(tester, editingDay: today);
      await tester.enterText(find.byType(TextField), 'Hill sprints');
      await tester.pump();

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      verify(
        () => updateCheckIn(
          id: '1',
          photos: const [
            StoredPhoto('photos/1.jpg'),
            StoredPhoto('photos/2.jpg'),
          ],
          workoutType: WorkoutType.cardio,
          activity: null,
          effort: null,
          energy: null,
          note: 'Hill sprints',
        ),
      ).called(1);
      expect(find.text('previous screen'), findsOneWidget);
    });

    testWidgets('removing a photo counts as a change', (tester) async {
      await pumpForm(tester, editingDay: today);

      await tester.tap(find.byIcon(CupertinoIcons.xmark).first);
      await tester.pumpAndSettle();

      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('cannot be saved with no photos left', (tester) async {
      await pumpForm(tester, editingDay: today);

      await tester.tap(find.byIcon(CupertinoIcons.xmark).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.xmark).first);
      await tester.pumpAndSettle();

      expect(button(tester).label, 'Add a photo to continue');
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('an unchanged form closes straight away', (tester) async {
      await pumpForm(tester, editingDay: today);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('previous screen'), findsOneWidget);
    });

    testWidgets('asks before discarding changes', (tester) async {
      await pumpForm(tester, editingDay: today);
      await chooseWorkout(tester, 'Other');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard your changes?'), findsOneWidget);
    });

    testWidgets('explains if the check-in cannot be loaded', (tester) async {
      when(() => getCheckIn(any())).thenAnswer((_) async => null);

      await pumpForm(tester, editingDay: today);

      expect(find.text("Couldn't load this check-in"), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('previous screen'), findsOneWidget);
    });
  });

  group('leaving', () {
    testWidgets('an untouched form closes straight away', (tester) async {
      await pumpForm(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this check-in?'), findsNothing);
      expect(find.text('previous screen'), findsOneWidget);
    });

    testWidgets('choosing only a workout type closes straight away', (
      tester,
    ) async {
      await pumpForm(tester);
      await chooseWorkout(tester, 'Cardio');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('previous screen'), findsOneWidget);
    });

    testWidgets('with a photo, asks first, and can keep editing', (
      tester,
    ) async {
      await pumpForm(tester);
      await takePhoto(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this check-in?'), findsOneWidget);

      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this check-in?'), findsNothing);
      expect(find.byType(PhotoStrip), findsOneWidget);
    });

    testWidgets('with a photo, Discard closes the screen', (tester) async {
      await pumpForm(tester);
      await takePhoto(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(CheckInScreen), findsNothing);
      expect(find.text('previous screen'), findsOneWidget);
    });

    testWidgets('a typed note also asks first', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.byType(TextField), 'Leg day');
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard this check-in?'), findsOneWidget);
    });

    testWidgets('Cancel is disabled while saving', (tester) async {
      final saving = Completer<CheckIn>();
      stubSave(() => saving.future);
      await pumpForm(tester);
      await takePhoto(tester);
      await chooseWorkout(tester, 'Strength');

      await tester.tap(find.text('Save check-in'));
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
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
    }

    testWidgets('an empty form fits', (tester) async {
      await pumpForm(tester, textScale: 3);
      expect(tester.takeException(), isNull);

      await scrollToBottom(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a filled-in edit fits', (tester) async {
      await pumpForm(tester, editingDay: today, textScale: 3);
      expect(tester.takeException(), isNull);

      await scrollToBottom(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('workout types stack, so words stay whole', (tester) async {
      await pumpForm(tester, textScale: 3);
      await tester.dragUntilVisible(
        find.text('Strength'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Cardio')).dy,
        greaterThan(tester.getBottomLeft(find.text('Strength')).dy),
      );
    });

    testWidgets('a form with every message showing fits', (tester) async {
      when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => throw const PhotoUnavailable('denied'));
      stubSave(() async => throw const StorageFailure());
      await pumpForm(tester, textScale: 3);

      await takePhoto(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Strength'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save check-in'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await scrollToBottom(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the discard question fits', (tester) async {
      await pumpForm(tester, textScale: 3);
      await takePhoto(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    Future<void> expectLabelsAndTargets(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    }

    testWidgets('an empty form has labelled, comfortable controls', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);

      await expectLabelsAndTargets(tester);
      semantics.dispose();
    });

    testWidgets('a filled-in form does too', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester, editingDay: today);

      await expectLabelsAndTargets(tester);
      semantics.dispose();
    });

    testWidgets('text has enough contrast', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester, editingDay: today);

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });

    testWidgets('activities have labelled, comfortable targets, and a chosen '
        'one has enough contrast', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpForm(tester);
      await chooseWorkout(tester, 'Other');
      await chooseActivity(tester, 'Sport');

      await expectLabelsAndTargets(tester);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });

  testWidgets('ratings have labelled, comfortable targets, and a chosen one '
      'has enough contrast', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpForm(tester);
    await rate(tester, 'Effort', '100%');
    await rate(tester, 'Energy', '20%');

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  group('on the smallest iPhone at 3x text size', () {
    Future<void> expectFits(WidgetTester tester) async {
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('an empty form fits', (tester) async {
      await pumpForm(tester, textScale: 3, screen: smallestPhoneScreen);

      await expectFits(tester);
    });

    testWidgets('a filled-in edit fits', (tester) async {
      await pumpForm(
        tester,
        editingDay: today,
        textScale: 3,
        screen: smallestPhoneScreen,
      );

      await expectFits(tester);
    });

    testWidgets('Other with a chosen activity fits', (tester) async {
      await pumpForm(tester, textScale: 3, screen: smallestPhoneScreen);
      // The list builds lazily, so Other doesn't exist until scrolled to.
      await tester.scrollUntilVisible(
        find.text('Other'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await chooseWorkout(tester, 'Other');
      await chooseActivity(tester, 'Sport');

      await expectFits(tester);
    });

    testWidgets('it still fits with the keyboard up and an error showing', (
      tester,
    ) async {
      stubUpdate(() async => throw const StorageFailure());
      await pumpForm(
        tester,
        editingDay: today,
        textScale: 3,
        screen: smallestPhoneScreen,
      );
      await tester.dragUntilVisible(
        find.text('Mobility'),
        find.byType(ListView).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobility'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      // The iPhone SE keyboard, at the view's three pixels per point.
      tester.view.viewInsets = const FakeViewPadding(bottom: 216.0 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text("Couldn't save your check-in. Try again."),
        findsOneWidget,
      );
    });
  });
}
