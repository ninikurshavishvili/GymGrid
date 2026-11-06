import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/features/check_in/presentation/photo_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late _MockImagePicker imagePicker;
  late PhotoPicker photoPicker;

  setUpAll(() => registerFallbackValue(ImageSource.camera));

  setUp(() {
    imagePicker = _MockImagePicker();
    photoPicker = PhotoPicker(imagePicker);
  });

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
    stubPick(() async => XFile('/tmp/camera.jpg'));

    expect(await photoPicker.takePhoto(), '/tmp/camera.jpg');

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
    stubPick(() async => XFile('/tmp/library.heic'));

    expect(await photoPicker.pickFromLibrary(), '/tmp/library.heic');

    verify(
      () => imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 85,
        requestFullMetadata: false,
      ),
    ).called(1);
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
}
