import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens web pages over the app, in Safari's own view.
///
/// A class around `url_launcher` so that screens can be tested with a stand
/// in, rather than a platform channel.
class LinkOpener {
  const LinkOpener();

  /// Shows [url] in an in-app browser, like `SFSafariViewController`, so
  /// the user stays in GymGrid. Returns false if it couldn't be opened.
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } on PlatformException {
      return false;
    }
  }
}
