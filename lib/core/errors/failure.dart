/// An expected failure that the UI can explain to the user, such as the
/// device running out of storage.
///
/// Repositories catch low-level errors (SQLite, the file system and, later,
/// the network) and rethrow them as a [Failure], so presentation code
/// handles one type whatever the data source. Any other exception that
/// reaches a Cubit is a bug.
///
/// Sealed, so a `switch` over failures must cover every case, as with a
/// Swift `enum` conforming to `Error`. A remote data source would add a
/// `NetworkFailure` here, and the compiler would point at every place that
/// needs to handle it.
sealed class Failure implements Exception {
  const Failure({this.cause});

  /// The underlying error, kept for logging.
  final Object? cause;
}

/// On-device storage couldn't be read or written.
final class StorageFailure extends Failure {
  const StorageFailure({super.cause});

  @override
  String toString() =>
      cause == null ? 'StorageFailure' : 'StorageFailure: $cause';
}
