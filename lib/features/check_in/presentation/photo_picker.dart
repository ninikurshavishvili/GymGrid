import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

/// Thrown when the camera or photo library can't supply a photo, such as
/// when camera access is off.
class PhotoUnavailable implements Exception {
  const PhotoUnavailable(this.cause);

  /// The underlying error, kept for logging.
  final Object cause;

  @override
  String toString() => 'PhotoUnavailable: $cause';
}

/// Gets photos from the camera and the library.
///
/// A thin wrapper over the `image_picker` plugin, the way you'd put a
/// protocol in front of `UIImagePickerController`, so Cubits can be tested
/// without a device.
class PhotoPicker {
  PhotoPicker([ImagePicker? imagePicker])
    : _imagePicker = imagePicker ?? ImagePicker();

  /// Plenty for a phone screen, and keeps stored files small.
  static const double _maxWidth = 2048;
  static const int _imageQuality = 85;

  final ImagePicker _imagePicker;

  /// Opens the camera and returns the path of the photo taken, or null if
  /// the user cancelled. Throws [PhotoUnavailable] if access is off.
  ///
  /// A device without a camera, which in practice means the simulator, also
  /// returns null: the plugin shows its own alert instead of reporting an
  /// error.
  Future<String?> takePhoto() => _pick(ImageSource.camera);

  /// Opens the photo library and returns the path of the photo chosen, or
  /// null if the user cancelled. Throws [PhotoUnavailable] if it can't be
  /// read.
  Future<String?> pickFromLibrary() => _pick(ImageSource.gallery);

  /// Opens this app's page in the Settings app, where camera access can be
  /// turned back on.
  Future<void> openSettings() => launchUrl(Uri.parse('app-settings:'));

  Future<String?> _pick(ImageSource source) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: _maxWidth,
        imageQuality: _imageQuality,
        // Lets the library open with no permission prompt: the system picker
        // hands over only the chosen photo, so the app never needs access to
        // the rest. It doesn't strip metadata, so photos keep their EXIF data.
        requestFullMetadata: false,
      );
      return photo?.path;
    } on PlatformException catch (error) {
      throw PhotoUnavailable(error);
    }
  }
}
