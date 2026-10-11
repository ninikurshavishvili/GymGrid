import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/features/check_in/data/photo_store.dart';
import 'package:path/path.dart' as p;

void main() {
  // A real temporary folder per test, standing in for the app container:
  // `Documents/` for the store and `tmp/` for the camera's photos.
  late Directory container;
  late Directory documents;
  late PhotoStore store;

  setUp(() async {
    container = await Directory.systemTemp.createTemp('photo_store_test_');
    documents = await Directory(p.join(container.path, 'Documents')).create();
    store = PhotoStore(documents);
  });

  tearDown(() => container.delete(recursive: true));

  /// Writes a photo to `tmp/`, as the camera does, and returns its path.
  Future<String> sourcePhoto(
    String name, {
    List<int> bytes = const [1, 2, 3],
  }) async {
    final file = File(p.join(container.path, 'tmp', name));
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  File storedFile(String photoPath) => File(p.join(documents.path, photoPath));

  group('save', () {
    test('copies the photo byte for byte and keeps the source', () async {
      final bytes = List.generate(64 * 1024, (i) => i % 256);
      final source = await sourcePhoto('camera.jpg', bytes: bytes);

      final photoPath = await store.save(source, id: 'abc');

      expect(photoPath, 'photos/abc.jpg');
      expect(storedFile(photoPath).readAsBytesSync(), bytes);
      expect(File(source).readAsBytesSync(), bytes);
    });

    test('creates the photos folder on first save', () async {
      final folder = Directory(p.join(documents.path, 'photos'));
      expect(folder.existsSync(), isFalse);

      await store.save(await sourcePhoto('a.jpg'), id: 'a');

      expect(folder.existsSync(), isTrue);
    });

    test('keeps the source extension, lowercased', () async {
      expect(
        await store.save(await sourcePhoto('IMG_0001.HEIC'), id: 'a'),
        'photos/a.heic',
      );
      expect(
        await store.save(await sourcePhoto('shot.png'), id: 'b'),
        'photos/b.png',
      );
    });

    test('uses .jpg when the source has no extension', () async {
      expect(
        await store.save(await sourcePhoto('camera_output'), id: 'a'),
        'photos/a.jpg',
      );
      expect(
        await store.save(await sourcePhoto('ends_in_dot.'), id: 'b'),
        'photos/b.jpg',
      );
    });

    test('throws when the source is missing, and stores nothing', () async {
      final missing = p.join(container.path, 'tmp', 'missing.jpg');

      await expectLater(
        store.save(missing, id: 'a'),
        throwsA(isA<FileSystemException>()),
      );
      expect(storedFile('photos/a.jpg').existsSync(), isFalse);
    });

    test('rejects an id that is not a plain file name', () async {
      final source = await sourcePhoto('a.jpg');

      for (final id in ['', '.hidden', '../escaped', 'sub/a', r'sub\a']) {
        await expectLater(
          store.save(source, id: id),
          throwsArgumentError,
          reason: 'id "$id"',
        );
      }
      expect(File(p.join(documents.path, 'escaped.jpg')).existsSync(), isFalse);
    });
  });

  group('delete', () {
    test('deletes the photo', () async {
      final photoPath = await store.save(await sourcePhoto('a.jpg'), id: 'a');

      await store.delete(photoPath);

      expect(storedFile(photoPath).existsSync(), isFalse);
    });

    test('does nothing when the photo is already gone', () async {
      await expectLater(store.delete('photos/missing.jpg'), completes);
    });
  });

  group('uriOf', () {
    test('points at the photo inside the documents directory', () async {
      const bytes = [4, 5, 6];
      final photoPath = await store.save(
        await sourcePhoto('a.jpg', bytes: bytes),
        id: 'a',
      );

      final uri = store.uriOf(photoPath);

      expect(uri, Uri.file(p.join(documents.path, 'photos', 'a.jpg')));
      expect(File.fromUri(uri).readAsBytesSync(), bytes);
    });
  });

  group('deleteUnreferenced', () {
    test('deletes only the photos not listed', () async {
      final source = await sourcePhoto('a.jpg');
      final kept = await store.save(source, id: 'kept');
      final alsoKept = await store.save(source, id: 'also-kept');
      final orphan = await store.save(source, id: 'orphan');
      final notAPhoto = File(p.join(documents.path, 'other.txt'))
        ..writeAsStringSync('not in photos/');

      await store.deleteUnreferenced({kept, alsoKept});

      expect(storedFile(kept).existsSync(), isTrue);
      expect(storedFile(alsoKept).existsSync(), isTrue);
      expect(storedFile(orphan).existsSync(), isFalse);
      expect(notAPhoto.existsSync(), isTrue);
    });

    test('does nothing before the first photo is saved', () async {
      await expectLater(store.deleteUnreferenced(const {}), completes);
    });
  });

  group('rejects a path that is not photos/<file name>:', () {
    const unsafePaths = [
      'a.jpg',
      'other/a.jpg',
      '/photos/a.jpg',
      '../photos/a.jpg',
      'photos/',
      'photos/..',
      'photos/../a.jpg',
      'photos/sub/a.jpg',
      r'photos/..\a.jpg',
    ];

    for (final path in unsafePaths) {
      test(path, () async {
        expect(() => store.uriOf(path), throwsArgumentError);
        await expectLater(store.delete(path), throwsArgumentError);
      });
    }

    test('and leaves the file it points at alone', () async {
      final outside = File(p.join(documents.path, 'a.jpg'))
        ..writeAsStringSync('not a photo');

      await expectLater(store.delete('photos/../a.jpg'), throwsArgumentError);

      expect(outside.existsSync(), isTrue);
    });
  });
}
