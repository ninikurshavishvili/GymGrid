import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/features/check_in/data/uuid.dart';

void main() {
  final v4Format = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('generates lowercase version 4 UUIDs', () {
    final uuids = UuidGenerator();

    for (var i = 0; i < 100; i++) {
      expect(uuids.v4(), matches(v4Format));
    }
  });

  test('sets the version and variant bits whatever the random bytes', () {
    expect(
      UuidGenerator(_ConstantRandom(0x00)).v4(),
      '00000000-0000-4000-8000-000000000000',
    );
    expect(
      UuidGenerator(_ConstantRandom(0xff)).v4(),
      'ffffffff-ffff-4fff-bfff-ffffffffffff',
    );
  });

  test('generates a different UUID each time', () {
    final uuids = UuidGenerator();

    final generated = {for (var i = 0; i < 10000; i++) uuids.v4()};

    expect(generated, hasLength(10000));
  });

  test('generates the same sequence from the same seed', () {
    List<String> sequence(int seed) {
      final uuids = UuidGenerator(Random(seed));
      return [for (var i = 0; i < 3; i++) uuids.v4()];
    }

    expect(sequence(1), sequence(1));
    expect(sequence(1), isNot(sequence(2)));
  });
}

/// A [Random] that always returns [byte], to pin every random bit.
class _ConstantRandom extends Fake implements Random {
  _ConstantRandom(this.byte);

  final int byte;

  @override
  int nextInt(int max) => byte;
}
