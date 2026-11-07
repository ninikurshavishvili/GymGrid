import '../../../../core/errors/failure.dart';
import '../repositories/check_in_repository.dart';

/// Deletes all of the user's data: every check-in and every photo.
class DeleteAllCheckIns {
  const DeleteAllCheckIns({required CheckInRepository repository})
    : _repository = repository;

  final CheckInRepository _repository;

  /// Throws a [Failure] if anything couldn't be deleted. Calling it again
  /// deletes whatever is left.
  Future<void> call() => _repository.deleteAll();
}
