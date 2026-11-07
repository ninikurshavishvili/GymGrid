import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

/// Why the last attempt to get a photo failed.
enum PhotoProblem { cameraUnavailable, libraryUnavailable }

/// Thrown when the camera or photo library can't supply a photo, such as
/// when camera access is off.
class PhotoUnavailable implements Exception {
  const PhotoUnavailable(this.cause);

  /// The underlying error, kept for logging.
  final Object cause;

  @override
  String toString() => 'PhotoUnavailable: $cause';
}

/// Gets photos from the camera and the library, and cleans up after them.
///
/// A thin wrapper over the `image_picker` plugin, the way you'd put a
/// protocol in front of `UIImagePickerController`, so Cubits can be tested
/// without a device.
///
/// The plugin hands over each photo as a file in a temporary folder, which
/// iOS empties only when it chooses. A check-in stores its own copy,
/// so these files are moved into [folder] as they arrive and deleted with
/// [discard] once they're stored or abandoned. That way no photo outlives
/// its check-in, and "Delete all data" leaves nothing behind.
class PhotoPicker {
  PhotoPicker({required this.folder, ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  /// The picked photos waiting to be stored. Only this class writes here,
  /// so it can be emptied without touching anyone else's files.
  final Directory folder;

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
  Future<void> openSettings() async {
    try {
      await launchUrl(Uri.parse('app-settings:'));
    } on PlatformException {
      // The message on screen already says where the setting is, so failing
      // to jump there isn't worth a second error.
    }
  }

  /// Deletes a photo this picker returned, once it's stored or no longer
  /// wanted.
  ///
  /// Never fails: a file that can't be deleted now goes at the next launch.
  /// Paths outside [folder] are left alone.
  Future<void> discard(String path) async {
    if (!p.isWithin(folder.path, path)) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone, or removed by [discardAll] at the next launch.
    }
  }

  /// Deletes every photo still waiting, such as one from a form that was
  /// open when the app was closed.
  ///
  /// Call it only when no form can be open, which is at launch. Never
  /// fails, for the same reason as [discard].
  Future<void> discardAll() async {
    try {
      await folder.delete(recursive: true);
    } on FileSystemException {
      // Nothing picked yet, or tried again at the next launch.
    }
  }

  Future<String?> _pick(ImageSource source) async {
    final XFile? photo;
    try {
      photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: _maxWidth,
        imageQuality: _imageQuality,
        // Lets the library open with no permission prompt: the system picker
        // hands over only the chosen photo, so the app never needs access to
        // the rest. It doesn't strip metadata, so photos keep their EXIF data.
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      throw PhotoUnavailable(error);
    }
    return photo == null ? null : _moveIntoFolder(photo.path);
  }

  /// Moves the plugin's file into [folder], keeping its name.
  ///
  /// Both are inside the app's own container, so this is a rename rather
  /// than a copy. If it fails anyway, the photo is still usable where it
  /// is: it just isn't cleaned up early.
  Future<String> _moveIntoFolder(String path) async {
    try {
      await folder.create(recursive: true);
      final moved = await File(
        path,
      ).rename(p.join(folder.path, p.basename(path)));
      return moved.path;
    } on FileSystemException {
      return path;
    }
  }
}
