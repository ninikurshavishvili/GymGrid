import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/app/router.dart';
import 'package:gym_grid/core/date/calendar_day.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in.dart';
import 'package:gym_grid/features/check_in/domain/entities/check_in_photo.dart';
import 'package:gym_grid/features/check_in/domain/entities/other_activity.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';
import 'package:gym_grid/features/check_in/domain/entities/workout_type.dart';
import 'package:gym_grid/features/check_in/domain/repositories/photo_locator.dart';
import 'package:gym_grid/features/check_in/domain/usecases/delete_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/update_check_in.dart';
import 'package:gym_grid/features/check_in/domain/usecases/watch_check_in.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:gym_grid/features/check_in/presentation/workout_type_labels.dart';
import 'package:gym_grid/features/progress/presentation/day_detail_cubit.dart';
import 'package:gym_grid/features/progress/presentation/day_detail_screen.dart';
import 'package:gym_grid/features/progress/presentation/widgets/photo_pager.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_themed.dart';

class _MockWatchCheckIn extends Mock implements WatchCheckIn {}

class _MockUpdateCheckIn extends Mock implements UpdateCheckIn {}

class _MockDeleteCheckIn extends Mock implements DeleteCheckIn {}

class _MockPhotoPicker extends Mock implements PhotoPicker {}

/// Rejects anything outside `photos/`, as `PhotoStore` does.
class _FakePhotoLocator implements PhotoLocator {
  const _FakePhotoLocator();

  @override
  Uri uriOf(String photoPath) {
    if (!photoPath.startsWith('photos/')) throw ArgumentError(photoPath);
    return Uri.file('/no/such/folder/$photoPath');
  }
}

void main() {
  late _MockWatchCheckIn watchCheckIn;
  late _MockUpdateCheckIn updateCheckIn;
  late _MockDeleteCheckIn deleteCheckIn;
  late _MockPhotoPicker photoPicker;
  late StreamController<CheckIn?> checkIns;

  final day = CalendarDay(2026, 11, 6);

  CheckIn checkInWith({
    List<String> photoPaths = const ['photos/1.jpg'],
    WorkoutType workoutType = WorkoutType.strength,
    OtherActivity? activity,
    String? note = 'Deadlift PR',
    Rating? effort,
    Rating? energy,
  }) {
    return CheckIn(
      id: '1',
      date: day,
      photoPaths: photoPaths,
      workoutType: workoutType,
      activity: activity,
      note: note,
      effort: effort,
      energy: energy,
      createdAt: DateTime(2026, 11, 6, 7, 42),
    );
  }

  setUpAll(() {
    registerFallbackValue(WorkoutType.other);
    registerFallbackValue(OtherActivity.sport);
    registerFallbackValue(Rating.medium);
    registerFallbackValue(<CheckInPhoto>[]);
  });

  setUp(() {
    watchCheckIn = _MockWatchCheckIn();
    updateCheckIn = _MockUpdateCheckIn();
    deleteCheckIn = _MockDeleteCheckIn();
    photoPicker = _MockPhotoPicker();
    when(() => photoPicker.discard(any())).thenAnswer((_) async {});
    // Broadcast, because closing a plain controller that nothing ever
    // listened to never finishes.
    checkIns = StreamController<CheckIn?>.broadcast();
    addTearDown(checkIns.close);
    when(() => watchCheckIn(day)).thenAnswer((_) => checkIns.stream);
  });

  /// Pumps the screen over a stand-in home, with [initial] on the stream.
  Future<void> pumpDay(
    WidgetTester tester,
    CheckIn? initial, {
    double textScale = 1,
    Size screen = phoneScreen,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('home screen'),
          routes: [
            GoRoute(
              path: 'day/:date',
              builder: (context, state) => BlocProvider(
                create: (_) => DayDetailCubit(
                  day: day,
                  watchCheckIn: watchCheckIn,
                  updateCheckIn: updateCheckIn,
                  deleteCheckIn: deleteCheckIn,
                  photoPicker: photoPicker,
                )..watch(),
                child: DayDetailScreen(
                  day: day,
                  photoLocator: const _FakePhotoLocator(),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => const Text('edit form'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScreen(tester, router, textScale: textScale, screen: screen);
    unawaited(router.push(AppRoutes.dayDetail(day)));
    await tester.pump();
    checkIns.add(initial);
    await tester.pumpAndSettle();
  }

  group('content', () {
    testWidgets('shows the day, workout, time and note', (tester) async {
      await pumpDay(tester, checkInWith());

      expect(find.text('Fri, Nov 6'), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('7:42 AM'), findsOneWidget);
      expect(find.text('Deadlift PR'), findsOneWidget);
      expect(find.byType(PhotoPager), findsOneWidget);
    });

    testWidgets("names an Other workout by its activity, with the activity's "
        'icon', (tester) async {
      await pumpDay(
        tester,
        checkInWith(
          workoutType: WorkoutType.other,
          activity: OtherActivity.sport,
        ),
      );

      expect(find.text('Sport'), findsOneWidget);
      expect(find.byIcon(OtherActivity.sport.icon), findsOneWidget);
      expect(find.text('Other'), findsNothing);
    });

    testWidgets('calls an Other workout without an activity "Workout"', (
      tester,
    ) async {
      await pumpDay(tester, checkInWith(workoutType: WorkoutType.other));

      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
      expect(find.byIcon(WorkoutType.other.icon), findsNothing);
    });

    testWidgets('leaves out a missing note', (tester) async {
      await pumpDay(tester, checkInWith(note: null));

      expect(tester.takeException(), isNull);
      expect(find.text('Strength'), findsOneWidget);
    });

    testWidgets('shows the ratings, read out together', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDay(
        tester,
        checkInWith(effort: Rating.high, energy: Rating.low),
      );

      expect(find.text('Effort'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('Energy'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.bySemanticsLabel('Effort 80%, Energy 40%'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('shows only a rating that was given', (tester) async {
      await pumpDay(tester, checkInWith(energy: Rating.max));

      expect(find.text('Energy'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Effort'), findsNothing);
    });

    testWidgets('shows no ratings when there are none', (tester) async {
      await pumpDay(tester, checkInWith());

      expect(find.text('Effort'), findsNothing);
      expect(find.text('Energy'), findsNothing);
    });

    testWidgets('survives a photo path it cannot locate', (tester) async {
      await pumpDay(tester, checkInWith(photoPaths: const ['../outside.jpg']));

      expect(tester.takeException(), isNull);
      expect(find.byType(PhotoPager), findsOneWidget);
    });

    testWidgets('updates by itself when the check-in changes', (tester) async {
      await pumpDay(tester, checkInWith());

      checkIns.add(checkInWith(note: 'Edited'));
      await tester.pumpAndSettle();

      expect(find.text('Edited'), findsOneWidget);
    });
  });

  group('photos', () {
    const twoPhotos = ['photos/1.jpg', 'photos/2.jpg'];

    testWidgets('one photo needs no page dots', (tester) async {
      await pumpDay(tester, checkInWith());

      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('several show a dot each and can be swiped through', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpDay(tester, checkInWith(photoPaths: twoPhotos));

      expect(find.byType(AnimatedContainer), findsNWidgets(2));
      expect(find.bySemanticsLabel('Photo 1 of 2'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Photo 2 of 2'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a newly added photo slides into view', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDay(tester, checkInWith());

      checkIns.add(checkInWith(photoPaths: twoPhotos));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Photo 2 of 2'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('adding a photo', () {
    Future<void> addFrom(WidgetTester tester, String source) async {
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(source));
      await tester.pumpAndSettle();
    }

    testWidgets('asks where from, then stores it on the check-in', (
      tester,
    ) async {
      when(
        () => photoPicker.pickFromLibrary(),
      ).thenAnswer((_) async => '/tmp/new.jpg');
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
      ).thenAnswer((_) async => checkInWith());
      await pumpDay(tester, checkInWith());

      await addFrom(tester, 'Choose from Library');

      verify(
        () => updateCheckIn(
          id: '1',
          photos: const [
            StoredPhoto('photos/1.jpg'),
            PickedPhoto('/tmp/new.jpg'),
          ],
          workoutType: WorkoutType.strength,
          activity: null,
          effort: null,
          energy: null,
          note: 'Deadlift PR',
        ),
      ).called(1);
    });

    testWidgets('explains when camera access is off', (tester) async {
      when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => throw const PhotoUnavailable('denied'));
      await pumpDay(tester, checkInWith());

      await addFrom(tester, 'Take Photo');

      expect(find.textContaining('Camera access is off'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('explains when the photo cannot be stored', (tester) async {
      when(
        () => photoPicker.takePhoto(),
      ).thenAnswer((_) async => '/tmp/new.jpg');
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
      ).thenAnswer((_) async => throw const StorageFailure());
      await pumpDay(tester, checkInWith());

      await addFrom(tester, 'Take Photo');

      expect(find.text("Couldn't add your photo. Try again."), findsOneWidget);
    });

    testWidgets('is not offered once the check-in is full', (tester) async {
      await pumpDay(
        tester,
        checkInWith(
          photoPaths: [
            for (var i = 0; i < CheckIn.maxPhotos; i++) 'photos/$i.jpg',
          ],
        ),
      );

      expect(find.text('Add photo'), findsNothing);
    });
  });

  testWidgets('Back returns to the previous screen', (tester) async {
    await pumpDay(tester, checkInWith());

    await tester.tap(find.byIcon(CupertinoIcons.back));
    await tester.pumpAndSettle();

    expect(find.byType(DayDetailScreen), findsNothing);
    expect(find.text('home screen'), findsOneWidget);
  });

  testWidgets('VoiceOver gets one working Back control', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpDay(tester, checkInWith());

    expect(
      tester.getSemantics(find.bySemanticsLabel('Back')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('VoiceOver can activate the actions', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpDay(tester, checkInWith());

    for (final label in ['Add photo', 'Delete check-in']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(isButton: true, hasTapAction: true, isEnabled: true),
        reason: label,
      );
    }
    semantics.dispose();
  });

  testWidgets('Edit opens the form for this day', (tester) async {
    await pumpDay(tester, checkInWith());

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('edit form'), findsOneWidget);
  });

  group('deleting', () {
    Future<void> confirmDelete(WidgetTester tester) async {
      await tester.tap(find.text('Delete check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, naming what will go', (tester) async {
      await pumpDay(tester, checkInWith());

      await tester.tap(find.text('Delete check-in'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this check-in?'), findsOneWidget);
      expect(
        find.text('Its photo will be removed from GymGrid.'),
        findsOneWidget,
      );
      verifyNever(() => deleteCheckIn(any()));
    });

    testWidgets('says photos when there are several', (tester) async {
      await pumpDay(
        tester,
        checkInWith(photoPaths: const ['photos/1.jpg', 'photos/2.jpg']),
      );

      await tester.tap(find.text('Delete check-in'));
      await tester.pumpAndSettle();

      expect(
        find.text('Its photos will be removed from GymGrid.'),
        findsOneWidget,
      );
    });

    testWidgets('Cancel keeps the check-in', (tester) async {
      await pumpDay(tester, checkInWith());

      await tester.tap(find.text('Delete check-in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => deleteCheckIn(any()));
      expect(find.byType(DayDetailScreen), findsOneWidget);
    });

    testWidgets('confirming deletes and returns home', (tester) async {
      when(() => deleteCheckIn('1')).thenAnswer((_) async {});
      await pumpDay(tester, checkInWith());

      await confirmDelete(tester);

      verify(() => deleteCheckIn('1')).called(1);
      expect(find.byType(DayDetailScreen), findsNothing);
      expect(find.text('home screen'), findsOneWidget);
    });

    testWidgets('a failure explains and stays on the check-in', (tester) async {
      when(
        () => deleteCheckIn('1'),
      ).thenAnswer((_) async => throw const StorageFailure());
      await pumpDay(tester, checkInWith());

      await confirmDelete(tester);

      expect(
        find.text("Couldn't delete this check-in. Try again."),
        findsOneWidget,
      );
      expect(find.text('Strength'), findsOneWidget);
    });
  });

  group('other states', () {
    testWidgets('an empty day says so', (tester) async {
      await pumpDay(tester, null);

      expect(find.text('No check-in on this day'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('a failure offers to try again', (tester) async {
      final retry = StreamController<CheckIn?>.broadcast();
      addTearDown(retry.close);
      when(
        () => watchCheckIn(day),
      ).thenAnswer((_) => Stream.error(const StorageFailure()));
      final router = GoRouter(
        initialLocation: '/day',
        routes: [
          GoRoute(
            path: '/day',
            builder: (context, state) => BlocProvider(
              create: (_) => DayDetailCubit(
                day: day,
                watchCheckIn: watchCheckIn,
                updateCheckIn: updateCheckIn,
                deleteCheckIn: deleteCheckIn,
                photoPicker: photoPicker,
              )..watch(),
              child: DayDetailScreen(
                day: day,
                photoLocator: const _FakePhotoLocator(),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpScreen(tester, router);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load this check-in"), findsOneWidget);

      when(() => watchCheckIn(day)).thenAnswer((_) => retry.stream);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      retry.add(checkInWith());
      await tester.pumpAndSettle();

      expect(find.text('Strength'), findsOneWidget);
    });
  });

  group('at 3x text size', () {
    testWidgets('a full check-in fits', (tester) async {
      await pumpDay(
        tester,
        checkInWith(
          photoPaths: const ['photos/1.jpg', 'photos/2.jpg'],
          note: 'A long note about the session ' * 6,
          effort: Rating.max,
          energy: Rating.max,
        ),
        textScale: 3,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty day fits', (tester) async {
      await pumpDay(tester, null, textScale: 3);

      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('controls are labelled and comfortable to tap', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDay(tester, checkInWith());

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('text has enough contrast', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDay(tester, checkInWith());

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });

  group('on the smallest iPhone at 3x text size', () {
    testWidgets('a full check-in fits', (tester) async {
      await pumpDay(
        tester,
        checkInWith(
          photoPaths: const ['photos/1.jpg', 'photos/2.jpg'],
          note: 'A long note about the session ' * 6,
          effort: Rating.max,
          energy: Rating.max,
        ),
        textScale: 3,
        screen: smallestPhoneScreen,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty day fits', (tester) async {
      await pumpDay(tester, null, textScale: 3, screen: smallestPhoneScreen);

      expect(tester.takeException(), isNull);
    });
  });
}
