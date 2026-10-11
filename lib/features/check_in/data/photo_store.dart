import 'dart:io';

import 'package:path/path.dart' as p;

/// Keeps check-in photos as files in the app's documents directory.
///
/// Each photo is stored as `photos/<check-in id><extension>`, and callers
/// only ever hold that relative path: on iOS the container's absolute path
/// changes across app updates, so an absolute path would go stale.
///
/// Every method that takes a path accepts exactly `photos/<file name>` and
/// throws [ArgumentError] for anything else, so a bad path, say from a
/// corrupted database, can't reach a file outside the folder. File system
/// errors propagate as [FileSystemException]s for the repository to map to
/// a `StorageFailure`.
class PhotoStore {
  const PhotoStore(this._documentsDirectory);

  static const _folderName = 'photos';

  final Directory _documentsDirectory;

  Directory get _folder =>
      Directory(p.join(_documentsDirectory.path, _folderName));

  /// Copies the photo at [sourcePath] into the store as the photo for the
  /// check-in [id], and returns its relative path, e.g. `photos/<id>.jpg`.
  ///
  /// Keeps the source's extension, lowercased, or uses `.jpg` if it has
  /// none. The source is left in place, so a failed save can be retried.
  Future<String> save(String sourcePath, {required String id}) async {
    final photoPath = '$_folderName/$id${_extensionOf(sourcePath)}';
    // Checked before anything touches the disk, and through the same rule
    // as the other methods, so every path returned here is accepted there.
    final target = _fileAt(photoPath);

    await _folder.create(recursive: true);
    await File(sourcePath).copy(target.path);
    return photoPath;
  }

  /// Deletes the photo at [photoPath]. A photo that is already gone is not
  /// an error.
  Future<void> delete(String photoPath) async {
    final file = _fileAt(photoPath);
    // Deleting and catching "not found" avoids a separate existence check,
    // which could be out of date by the time the delete runs.
    try {
      await file.delete();
    } on PathNotFoundException {
      // Nothing to delete.
    }
  }

  /// The `file:` URI of the photo at [photoPath], for displaying it.
  Uri uriOf(String photoPath) => _fileAt(photoPath).uri;

  /// Deletes every photo whose path isn't in [keep].
  ///
  /// This removes photos left behind when the app stopped between copying
  /// a photo and saving its check-in. Call it only while no save is in
  /// progress, as at launch; otherwise it could delete a photo that is
  /// about to be saved.
  Future<void> deleteUnreferenced(Set<String> keep) async {
    final List<FileSystemEntity> entries;
    try {
      entries = await _folder.list().toList();
    } on PathNotFoundException {
      return; // No photo has been saved yet.
    }

    for (final file in entries.whereType<File>()) {
      if (!keep.contains('$_folderName/${p.basename(file.path)}')) {
        await file.delete();
      }
    }
  }

  /// The file at [photoPath], which must be `photos/` followed by a plain
  /// file name.
  File _fileAt(String photoPath) {
    const prefix = '$_folderName/';
    final fileName = photoPath.startsWith(prefix)
        ? photoPath.substring(prefix.length)
        : '';

    // A file name with no separators that doesn't start with a dot can't
    // be `.` or `..`, so it can't lead out of the folder.
    final isPlainFileName =
        fileName.isNotEmpty &&
        !fileName.startsWith('.') &&
        !fileName.contains('/') &&
        !fileName.contains(r'\');
    if (!isPlainFileName) {
      throw ArgumentError.value(
        photoPath,
        'photoPath',
        'must be $_folderName/<file name>',
      );
    }

    return File(p.join(_folder.path, fileName));
  }

  /// The extension of [sourcePath], lowercased, such as `.heic`, or `.jpg`
  /// if it has none.
  static String _extensionOf(String sourcePath) {
    final extension = p.extension(sourcePath).toLowerCase();
    // `p.extension` returns `.` for a name ending in a dot.
    return extension.length > 1 ? extension : '.jpg';
  }
}
