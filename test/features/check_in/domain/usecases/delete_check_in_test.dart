import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/errors/failure.dart';
import 'package:gym_grid/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:gym_grid/features/check_in/domain/usecases/delete_check_in.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

void main() {
  late _MockCheckInRepository repository;
  late DeleteCheckIn deleteCheckIn;

  setUp(() {
    repository = _MockCheckInRepository();
    deleteCheckIn = DeleteCheckIn(repository: repository);
  });

  test('deletes the check-in with the given id', () async {
    when(() => repository.delete('1')).thenAnswer((_) async {});

    await deleteCheckIn('1');

    verify(() => repository.delete('1')).called(1);
  });

  test('passes a storage failure on to the caller', () async {
    when(
      () => repository.delete('1'),
    ).thenAnswer((_) async => throw const StorageFailure());

    await expectLater(deleteCheckIn('1'), throwsA(isA<StorageFailure>()));
  });
}
