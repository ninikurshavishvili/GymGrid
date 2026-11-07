import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/usecases/delete_all_check_ins.dart';
import 'package:gym_grid/features/settings/presentation/link_opener.dart';
import 'package:gym_grid/features/settings/presentation/settings_cubit.dart';
import 'package:gym_grid/features/settings/presentation/settings_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeleteAllCheckIns extends Mock implements DeleteAllCheckIns {}

class _MockLinkOpener extends Mock implements LinkOpener {}

void main() {
  late _MockDeleteAllCheckIns deleteAllCheckIns;
  late _MockLinkOpener linkOpener;

  final policy = Uri.parse('https://example.com/privacy');

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    deleteAllCheckIns = _MockDeleteAllCheckIns();
    linkOpener = _MockLinkOpener();
  });

  SettingsCubit buildCubit() => SettingsCubit(
    deleteAllCheckIns: deleteAllCheckIns,
    linkOpener: linkOpener,
  );

  test('starts with nothing deleted', () {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    expect(cubit.state, const SettingsState());
  });

  group('deleting all data', () {
    blocTest<SettingsCubit, SettingsState>(
      'reports progress, then that it is done',
      setUp: () => when(() => deleteAllCheckIns()).thenAnswer((_) async {}),
      build: buildCubit,
      act: (cubit) => cubit.deleteAllData(),
      expect: () => const [
        SettingsState(deletion: DataDeletion.inProgress),
        SettingsState(deletion: DataDeletion.done),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'reports a failure',
      setUp: () => when(
        () => deleteAllCheckIns(),
      ).thenAnswer((_) async => throw const StorageFailure()),
      build: buildCubit,
      act: (cubit) => cubit.deleteAllData(),
      expect: () => const [
        SettingsState(deletion: DataDeletion.inProgress),
        SettingsState(deletion: DataDeletion.failed),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'can try again after a failure',
      setUp: () => when(() => deleteAllCheckIns()).thenAnswer((_) async {}),
      build: buildCubit,
      seed: () => const SettingsState(deletion: DataDeletion.failed),
      act: (cubit) => cubit.deleteAllData(),
      expect: () => const [
        SettingsState(deletion: DataDeletion.inProgress),
        SettingsState(deletion: DataDeletion.done),
      ],
    );

    test('ignores a second request while the first is running', () async {
      final finish = Completer<void>();
      when(() => deleteAllCheckIns()).thenAnswer((_) => finish.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      unawaited(cubit.deleteAllData());
      unawaited(cubit.deleteAllData());
      finish.complete();
      await Future<void>.delayed(Duration.zero);

      verify(() => deleteAllCheckIns()).called(1);
      expect(cubit.state.deletion, DataDeletion.done);
    });

    test('a result after the screen closes is dropped', () async {
      final finish = Completer<void>();
      when(() => deleteAllCheckIns()).thenAnswer((_) => finish.future);
      final cubit = buildCubit();

      unawaited(cubit.deleteAllData());
      await cubit.close();
      finish.complete();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.deletion, DataDeletion.inProgress);
    });
  });

  group('opening a link', () {
    blocTest<SettingsCubit, SettingsState>(
      'opens it, and says nothing when that works',
      setUp: () => when(() => linkOpener.open(any())).thenAnswer((_) async {
        return true;
      }),
      build: buildCubit,
      act: (cubit) => cubit.openLink(policy),
      expect: () => const <SettingsState>[],
      verify: (_) => verify(() => linkOpener.open(policy)).called(1),
    );

    blocTest<SettingsCubit, SettingsState>(
      'says so when it cannot be opened',
      setUp: () =>
          when(() => linkOpener.open(any())).thenAnswer((_) async => false),
      build: buildCubit,
      act: (cubit) => cubit.openLink(policy),
      expect: () => const [SettingsState(couldNotOpenLink: true)],
    );

    blocTest<SettingsCubit, SettingsState>(
      'clears the message when trying again',
      setUp: () =>
          when(() => linkOpener.open(any())).thenAnswer((_) async => true),
      build: buildCubit,
      seed: () => const SettingsState(couldNotOpenLink: true),
      act: (cubit) => cubit.openLink(policy),
      expect: () => const [SettingsState()],
    );
  });
}
