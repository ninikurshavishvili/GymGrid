/// Finds a check-in's photo so a screen can display it.
///
/// `CheckIn.photoPath` is relative, and only the storage layer knows what
/// it's relative to. Presentation can't import that layer, so screens get
/// this one capability instead, the way a narrow Swift protocol exposes a
/// single method of a larger type.
abstract interface class PhotoLocator {
  /// The file URI for a check-in's relative [photoPath], for display.
  Uri uriOf(String photoPath);
}
