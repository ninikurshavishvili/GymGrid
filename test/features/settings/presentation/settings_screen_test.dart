import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/usecases/delete_all_check_ins.dart';
import 'package:gym_grid/features/settings/presentation/link_opener.dart';
import 'package:gym_grid/features/settings/presentation/settings_cubit.dart';
import 'package:gym_grid/features/settings/presentation/settings_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_themed.dart';

class _MockDeleteAllCheckIns extends Mock implements DeleteAllCheckIns {}

class _MockLinkOpener extends Mock implements LinkOpener {}

void main() {
  late _MockDeleteAllCheckIns deleteAllCheckIns;
  late _MockLinkOpener linkOpener;
  late List<String?> haptics;

  final policy = Uri.parse('https://example.com/privacy');

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    deleteAllCheckIns = _MockDeleteAllCheckIns();
    linkOpener = _MockLinkOpener();
    haptics = [];
    when(() => deleteAllCheckIns()).thenAnswer((_) async {});
    when(() => linkOpener.open(any())).thenAnswer((_) async => true);
  });

  /// Pumps Settings over a stand-in home, so Back has somewhere to go.
  Future<void> pumpSettings(
    WidgetTester tester, {
    Uri? privacyPolicy,
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
          builder: (context, state) => const Text('home'),
          routes: [
            GoRoute(
              path: 'settings',
              builder: (context, state) => BlocProvider(
                create: (_) => SettingsCubit(
                  deleteAllCheckIns: deleteAllCheckIns,
                  linkOpener: linkOpener,
                ),
                child: SettingsScreen(
                  version: '1.0.0 (1)',
                  privacyPolicy: privacyPolicy,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScreen(tester, router, textScale: textScale, screen: screen);
    unawaited(router.push('/settings'));
    await tester.pumpAndSettle();
  }

  /// Taps Delete all data, then [answer] in the dialog.
  Future<void> deleteAll(
    WidgetTester tester, {
    String answer = 'Delete All',
  }) async {
    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete all data?'), findsOneWidget);

    await tester.tap(find.text(answer));
    await tester.pumpAndSettle();
  }

  group('content', () {
    testWidgets('says where data lives, and shows the version', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Settings'), findsWidgets);
      expect(
        find.textContaining(
          'keeps your check-ins and photos on this '
          'device',
        ),
        findsOneWidget,
      );
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('1.0.0 (1)'), findsOneWidget);
      expect(find.text('Made by Nini Kurshavishvili'), findsOneWidget);
    });

    testWidgets('leaves the privacy policy out until it has an address', (
      tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('Privacy policy'), findsNothing);
    });

    testWidgets('opens the privacy policy once it has one', (tester) async {
      await pumpSettings(tester, privacyPolicy: policy);

      await tester.tap(find.text('Privacy policy'));
      await tester.pump();

      verify(() => linkOpener.open(policy)).called(1);
      expect(find.textContaining("Couldn't open"), findsNothing);
    });

    testWidgets('says so when the privacy policy cannot be opened', (
      tester,
    ) async {
      when(() => linkOpener.open(any())).thenAnswer((_) async => false);
      await pumpSettings(tester, privacyPolicy: policy);

      await tester.tap(find.text('Privacy policy'));
      await tester.pump();

      expect(
        find.text("Couldn't open the privacy policy. Try again."),
        findsOneWidget,
      );
    });

    testWidgets('Licenses opens the licenses page with the version', (
      tester,
    ) async {
      await pumpSettings(tester);

      await tester.ensureVisible(find.text('Licenses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Licenses'));
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('GymGrid'), findsWidgets);
    });

    testWidgets('Back returns to the previous screen', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });
  });

  group('deleting all data', () {
    testWidgets('asks first, and Cancel deletes nothing', (tester) async {
      await pumpSettings(tester);

      await deleteAll(tester, answer: 'Cancel');

      verifyNever(() => deleteAllCheckIns());
      expect(find.text('Delete all data?'), findsNothing);
    });

    testWidgets('deletes once confirmed, says so and gives a firm tap', (
      tester,
    ) async {
      await pumpSettings(tester);

      await deleteAll(tester);

      verify(() => deleteAllCheckIns()).called(1);
      expect(
        find.text('All check-ins and photos have been deleted.'),
        findsOneWidget,
      );
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
    });

    testWidgets('shows a spinner and cannot be started twice while running', (
      tester,
    ) async {
      final finish = Completer<void>();
      when(() => deleteAllCheckIns()).thenAnswer((_) => finish.future);
      await pumpSettings(tester);

      await tester.tap(find.text('Delete all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      await tester.tap(find.text('Delete all data'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Delete all data?'), findsNothing);

      finish.complete();
      await tester.pumpAndSettle();
      verify(() => deleteAllCheckIns()).called(1);
    });

    testWidgets('a failure says so, and trying again can succeed', (
      tester,
    ) async {
      var calls = 0;
      when(() => deleteAllCheckIns()).thenAnswer((_) async {
        if (++calls == 1) throw const StorageFailure();
      });
      await pumpSettings(tester);

      await deleteAll(tester);
      expect(
        find.text("Some data couldn't be deleted. Try again."),
        findsOneWidget,
      );

      await deleteAll(tester);
      expect(
        find.text('All check-ins and photos have been deleted.'),
        findsOneWidget,
      );
    });
  });

  group('accessibility', () {
    testWidgets('rows are their own controls, named with their value', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSettings(tester, privacyPolicy: policy);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Delete all data')),
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Privacy policy')),
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Version, 1.0.0 (1)')),
        isSemantics(isButton: false, hasTapAction: false),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Your data')),
        isSemantics(isHeader: true),
      );
      semantics.dispose();
    });

    testWidgets('announces when the data has been deleted', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSettings(tester);

      await deleteAll(tester);

      expect(
        tester.getSemantics(
          find.bySemanticsLabel('All check-ins and photos have been deleted.'),
        ),
        isSemantics(isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('every control has a label and a comfortable target', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSettings(tester, privacyPolicy: policy);

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('text has enough contrast', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSettings(tester, privacyPolicy: policy);

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  });

  group('on the smallest iPhone at 3x text size', () {
    Future<void> expectFits(WidgetTester tester) async {
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('the screen fits', (tester) async {
      await pumpSettings(
        tester,
        privacyPolicy: policy,
        textScale: 3,
        screen: smallestPhoneScreen,
      );

      await expectFits(tester);
    });

    testWidgets('a failure message fits', (tester) async {
      when(
        () => deleteAllCheckIns(),
      ).thenAnswer((_) async => throw const StorageFailure());
      await pumpSettings(tester, textScale: 3, screen: smallestPhoneScreen);
      await tester.scrollUntilVisible(
        find.text('Delete all data'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await deleteAll(tester);

      await expectFits(tester);
    });

    testWidgets('the version moves under its label, so both stay whole', (
      tester,
    ) async {
      await pumpSettings(tester, textScale: 3, screen: smallestPhoneScreen);
      await tester.scrollUntilVisible(
        find.text('1.0.0 (1)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('1.0.0 (1)')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('Version')).dy),
      );
    });
  });
}
