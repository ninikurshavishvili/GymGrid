import 'dart:math';

/// Generates random (version 4) UUIDs, used as check-in ids.
///
/// Dart's core library has no counterpart of Foundation's `UUID`, and a
/// package isn't worth adding for one short method.
class UuidGenerator {
  /// A generator that draws bytes from [random], or from a cryptographically
  /// secure source (like `SecRandomCopyBytes`) when none is given.
  ///
  /// Tests pass a seeded [Random] to get the same ids on every run.
  UuidGenerator([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  /// A new UUID in lowercase 8-4-4-4-12 form, such as
  /// `1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed`.
  String v4() {
    final bytes = [for (var i = 0; i < 16; i++) _random.nextInt(256)];

    // RFC 9562 reserves six of the 128 bits: the high nibble of byte 6 is
    // the version (4), and the top two bits of byte 8 are the variant (10).
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20),
    ].join('-');
  }
}
