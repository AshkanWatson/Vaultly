import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Cryptographically secure randomness backed by the OS CSPRNG.
class SecureRandomSource {
  SecureRandomSource._();

  static final Random _rng = Random.secure();

  /// Returns [length] random bytes.
  static Uint8List bytes(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }

  /// Uniform random integer in `[0, max)`. `Random.secure().nextInt` is
  /// unbiased, so no extra rejection sampling is needed.
  static int nextInt(int max) => _rng.nextInt(max);

  /// In-place Fisher–Yates shuffle.
  static void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// A seeded pointycastle [SecureRandom] for APIs that require one
  /// (e.g. EC key generation).
  static SecureRandom pointyCastle() {
    final fortuna = FortunaRandom();
    fortuna.seed(KeyParameter(bytes(32)));
    return fortuna;
  }
}
