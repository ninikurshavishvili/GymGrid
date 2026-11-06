/// Finds a check-in's photo so a screen can display it.
///
/// `CheckIn.photoPaths` are relative, and only the storage layer knows what
/// they're relative to. Presentation can't import that layer, so screens get
/// this one capability instead, the way a narrow Swift protocol exposes a
/// single method of a larger type.
abstract interface class PhotoLocator {
  /// The file URI for a check-in's relative [photoPath], for display.
  Uri uriOf(String photoPath);
}
