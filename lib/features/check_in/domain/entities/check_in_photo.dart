import 'package:equatable/equatable.dart';

/// A photo in a check-in being edited, which may or may not be stored yet.
///
/// Sealed, like a Swift `enum` with associated values, so code that handles
/// a photo has to cover both cases.
sealed class CheckInPhoto extends Equatable {
  const CheckInPhoto();
}

/// A photo the check-in already has.
final class StoredPhoto extends CheckInPhoto {
  const StoredPhoto(this.photoPath);

  /// As in `CheckIn.photoPaths`.
  final String photoPath;

  @override
  List<Object> get props => [photoPath];
}

/// A photo just picked, not stored yet.
final class PickedPhoto extends CheckInPhoto {
  const PickedPhoto(this.sourcePath);

  /// An absolute path to a file such as the camera's temporary photo.
  final String sourcePath;

  @override
  List<Object> get props => [sourcePath];
}
