import '../../../../core/errors/failure.dart';
import '../repositories/check_in_repository.dart';

/// Deletes a check-in and its photo.
class DeleteCheckIn {
  const DeleteCheckIn({required CheckInRepository repository})
    : _repository = repository;

  final CheckInRepository _repository;

  /// Does nothing if there is no check-in with [id]. Throws a [Failure] if
  /// the check-in can't be deleted.
  Future<void> call(String id) => _repository.delete(id);
}
