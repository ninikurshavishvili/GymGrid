import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/check_in/domain/usecases/delete_all_check_ins.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

void main() {
  late _MockCheckInRepository repository;
  late DeleteAllCheckIns deleteAllCheckIns;

  setUp(() {
    repository = _MockCheckInRepository();
    deleteAllCheckIns = DeleteAllCheckIns(repository: repository);
  });

  test('deletes everything through the repository', () async {
    when(() => repository.deleteAll()).thenAnswer((_) async {});

    await deleteAllCheckIns();

    verify(() => repository.deleteAll()).called(1);
  });

  test('passes a storage failure on to the caller', () async {
    when(
      () => repository.deleteAll(),
    ).thenAnswer((_) async => throw const StorageFailure());

    await expectLater(deleteAllCheckIns(), throwsA(isA<StorageFailure>()));
  });
}
