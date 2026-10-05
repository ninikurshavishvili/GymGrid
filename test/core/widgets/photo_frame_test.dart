import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/widgets/photo_frame.dart';

import '../../helpers/pump_themed.dart';

/// A valid 1x1 transparent PNG.
final _pixel = MemoryImage(
  Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]),
);

/// Bytes that are not an image, standing in for a missing or corrupt file.
final _corrupt = MemoryImage(Uint8List.fromList(const [0, 1, 2, 3]));

void main() {
  group('without a photo', () {
    testWidgets('shows a placeholder that asks for a photo', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        PhotoFrame(
          image: null,
          semanticLabel: 'Check-in photo',
          onTapEmpty: () => taps++,
        ),
      );

      await tester.tap(find.text('Take a photo'));

      expect(taps, 1);
    });

    testWidgets('fits at 3x text size', (tester) async {
      await pumpThemed(
        tester,
        const PhotoFrame(image: null, semanticLabel: 'Check-in photo'),
        textScale: 3,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('with a photo', () {
    testWidgets('shows the caption and a working action', (tester) async {
      var retakes = 0;
      await pumpThemed(
        tester,
        PhotoFrame(
          image: _pixel,
          semanticLabel: 'Check-in photo',
          caption: '07:42 AM',
          captionAlignment: AlignmentDirectional.topStart,
          action: PhotoFrameAction(
            icon: Icons.refresh,
            label: 'Retake',
            onPressed: () => retakes++,
          ),
        ),
      );

      expect(find.text('07:42 AM'), findsOneWidget);
      await tester.tap(find.text('Retake'));
      expect(retakes, 1);
    });

    testWidgets('describes the photo and its action to screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpThemed(
        tester,
        PhotoFrame(
          image: _pixel,
          semanticLabel: 'Check-in photo',
          action: PhotoFrameAction(
            icon: Icons.refresh,
            label: 'Retake',
            onPressed: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Check-in photo')),
        isSemantics(isImage: true),
      );
      expect(
        tester.getSemantics(find.text('Retake')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('shows an unavailable state when the photo cannot load', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        PhotoFrame(image: _corrupt, semanticLabel: 'Check-in photo'),
      );
      // Image decoding runs outside the test's fake clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.text('Photo unavailable'), findsOneWidget);
    });
  });
}
