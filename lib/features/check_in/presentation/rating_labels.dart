import '../domain/entities/rating.dart';

/// How a [Rating] is written in the app.
///
/// Kept out of the domain, like `WorkoutTypeLabels`: the domain has the
/// number, and how it reads on screen is the presentation layer's call.
extension RatingLabel on Rating {
  /// "20%" to "100%". VoiceOver reads the sign as "percent".
  String get label => '$percent%';
}
