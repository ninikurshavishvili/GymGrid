/// Web pages the app links to, kept in one place.
abstract final class AppLinks {
  /// The privacy policy, which App Store Connect asks for too.
  ///
  /// Null until the policy is published. Settings leaves its row out until
  /// then, rather than open a page that isn't there.
  static const String? privacyPolicy = null;
}
