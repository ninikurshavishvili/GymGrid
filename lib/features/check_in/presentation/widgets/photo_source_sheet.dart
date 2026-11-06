import 'package:flutter/cupertino.dart';

/// Where a new photo comes from.
enum PhotoSource { camera, library }

/// Asks where to get a photo from, with the iOS action sheet. Returns null
/// if the user cancels.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) {
  return showCupertinoModalPopup<PhotoSource>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(PhotoSource.camera),
          child: const Text('Take Photo'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(PhotoSource.library),
          child: const Text('Choose from Library'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );
}
