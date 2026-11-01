import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'encoding.dart';
import 'secure_random.dart';

/// Argon2id parameters. Stored (unencrypted) in the vault header so they can
/// be raised in future versions without breaking existing vaults.
class KdfParams {
  const KdfParams({
    required this.salt,
    this.memoryKiB = defaultMemoryKiB,
    this.iterations = defaultIterations,
    this.parallelism = defaultParallelism,
  });

  /// Argon2id profile: 46 MiB, 2 passes, 1 lane. This is above the OWASP
  /// minimum (46 MiB / 1 pass) and unlocks in roughly half a second on a
  /// modern phone. Older vaults keep the parameters they were created with.
  static const int defaultMemoryKiB = 46 * 1024;
  static const int defaultIterations = 2;
  static const int defaultParallelism = 1;

  final Uint8List salt;
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  factory KdfParams.generate({
    int memoryKiB = defaultMemoryKiB,
    int iterations = defaultIterations,
    int parallelism = defaultParallelism,
  }) =>
      KdfParams(
        salt: SecureRandomSource.bytes(16),
        memoryKiB: memoryKiB,
        iterations: iterations,
        parallelism: parallelism,
      );

  Map<String, dynamic> toJson() => {
        'alg': 'argon2id',
        'v': 19,
        'm': memoryKiB,
        't': iterations,
        'p': parallelism,
        'salt': b64(salt),
      };

  factory KdfParams.fromJson(Map<String, dynamic> json) {
    if (json['alg'] != 'argon2id') {
      throw FormatException('Unsupported KDF: ${json['alg']}');
    }
    final m = json['m'] as int;
    final t = json['t'] as int;
    final p = json['p'] as int;
    // Refuse absurd values from a tampered header (DoS / downgrade).
    if (m < 8 * 1024 || m > 1024 * 1024 || t < 1 || t > 20 || p < 1 || p > 8) {
      throw const FormatException('KDF parameters out of range');
    }
    return KdfParams(
      salt: b64Decode(json['salt'] as String),
      memoryKiB: m,
      iterations: t,
      parallelism: p,
    );
  }
}

/// Derives a 256-bit key from [password] with Argon2id (RFC 9106).
Uint8List argon2idSync(
  Uint8List password,
  Uint8List salt, {
  required int memoryKiB,
  required int iterations,
  required int parallelism,
  int length = 32,
}) {
  final gen = Argon2BytesGenerator()
    ..init(Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      desiredKeyLength: length,
      iterations: iterations,
      memory: memoryKiB,
      lanes: parallelism,
      version: Argon2Parameters.ARGON2_VERSION_13,
    ));
  final out = Uint8List(length);
  gen.deriveKey(password, 0, out, 0);
  return out;
}

/// Derives the key-encryption key for [password] on a background isolate so
/// the UI never freezes while Argon2 runs.
Future<Uint8List> deriveKey(String password, KdfParams params) {
  final pw = Uint8List.fromList(utf8.encode(password));
  final salt = params.salt;
  final m = params.memoryKiB;
  final t = params.iterations;
  final p = params.parallelism;
  return Isolate.run(() {
    try {
      return argon2idSync(pw, salt,
          memoryKiB: m, iterations: t, parallelism: p);
    } finally {
      wipe(pw);
    }
  });
}
