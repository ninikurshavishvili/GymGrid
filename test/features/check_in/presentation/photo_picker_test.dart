import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late _MockImagePicker imagePicker;
  late Directory temporary;
  late Directory folder;
  late PhotoPicker photoPicker;

  setUpAll(() => registerFallbackValue(ImageSource.camera));

  setUp(() async {
    imagePicker = _MockImagePicker();
    // Stands in for the app's temporary directory, where the plugin writes.
    temporary = await Directory.systemTemp.createTemp('photo_picker_test_');
    folder = Directory(p.join(temporary.path, 'picked_photos'));
    photoPicker = PhotoPicker(folder: folder, imagePicker: imagePicker);
  });

  tearDown(() => temporary.delete(recursive: true));

  /// Writes a file where the plugin would, and returns its path.
  Future<String> pluginFile(String name) async {
    final file = File(p.join(temporary.path, name));
    await file.writeAsString(name);
    return file.path;
  }

  void stubPick(Future<XFile?> Function() answer) {
    when(
      () => imagePicker.pickImage(
        source: any(named: 'source'),
        maxWidth: any(named: 'maxWidth'),
        imageQuality: any(named: 'imageQuality'),
        requestFullMetadata: any(named: 'requestFullMetadata'),
      ),
    ).thenAnswer((_) => answer());
  }

  test('takes a photo with the camera, resized and without metadata', () async {
    final photo = await pluginFile('camera.jpg');
    stubPick(() async => XFile(photo));

    await photoPicker.takePhoto();

    verify(
      () => imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        imageQuality: 85,
        requestFullMetadata: false,
      ),
    ).called(1);
  });

  test('picks a photo from the library the same way', () async {
    final photo = await pluginFile('library.heic');
    stubPick(() async => XFile(photo));

    await photoPicker.pickFromLibrary();

    verify(
      () => imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 85,
        requestFullMetadata: false,
      ),
    ).called(1);
  });

  test("moves the plugin's file into its own folder", () async {
    final photo = await pluginFile('camera.jpg');
    stubPick(() async => XFile(photo));

    final path = await photoPicker.takePhoto();

    expect(path, p.join(folder.path, 'camera.jpg'));
    expect(File(path!).readAsStringSync(), 'camera.jpg');
    expect(File(photo).existsSync(), isFalse);
  });

  test('still returns the photo if it cannot be moved', () async {
    stubPick(() async => XFile(p.join(temporary.path, 'missing.jpg')));

    expect(
      await photoPicker.takePhoto(),
      p.join(temporary.path, 'missing.jpg'),
    );
  });

  test('returns null when the user cancels', () async {
    stubPick(() async => null);

    expect(await photoPicker.takePhoto(), isNull);
  });

  test('reports camera access being off', () async {
    stubPick(() async => throw PlatformException(code: 'camera_access_denied'));

    await expectLater(
      photoPicker.takePhoto(),
      throwsA(isA<PhotoUnavailable>()),
    );
  });

  group('discard', () {
    test('deletes a photo it picked', () async {
      stubPick(() async => XFile(await pluginFile('camera.jpg')));
      final path = await photoPicker.takePhoto();

      await photoPicker.discard(path!);

      expect(File(path).existsSync(), isFalse);
    });

    test('leaves files outside its folder alone', () async {
      final other = await pluginFile('not-mine.jpg');

      await photoPicker.discard(other);

      expect(File(other).existsSync(), isTrue);
    });

    test('does nothing for a photo already gone', () async {
      await photoPicker.discard(p.join(folder.path, 'gone.jpg'));
    });
  });

  group('discardAll', () {
    test('deletes every photo still waiting', () async {
      stubPick(() async => XFile(await pluginFile('first.jpg')));
      final first = await photoPicker.takePhoto();
      stubPick(() async => XFile(await pluginFile('second.jpg')));
      final second = await photoPicker.pickFromLibrary();

      await photoPicker.discardAll();

      expect(File(first!).existsSync(), isFalse);
      expect(File(second!).existsSync(), isFalse);
    });

    test('does nothing before anything is picked', () async {
      await photoPicker.discardAll();

      expect(folder.existsSync(), isFalse);
    });

    test('picking still works afterwards', () async {
      await photoPicker.discardAll();
      stubPick(() async => XFile(await pluginFile('camera.jpg')));

      final path = await photoPicker.takePhoto();

      expect(File(path!).existsSync(), isTrue);
    });
  });
}
