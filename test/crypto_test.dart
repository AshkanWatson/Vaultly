import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/core/crypto/aead.dart';
import 'package:vaultly/core/crypto/encoding.dart';
import 'package:vaultly/core/crypto/kdf.dart';

void main() {
  test('Argon2id matches the reference implementation test vector', () {
    // phc-winner-argon2 src/test.c: argon2id, t=2, m=2^16, p=1.
    final out = argon2idSync(
      Uint8List.fromList(utf8.encode('password')),
      Uint8List.fromList(utf8.encode('somesalt')),
      memoryKiB: 65536,
      iterations: 2,
      parallelism: 1,
    );
    expect(hex(out),
        '09316115d5cf24ed5a15a31a3ba326e5cf32edc24702987c02b6566f61913cf7');
  });

  test('AES-256-GCM matches NIST test case 14 (zero key, zero block)', () {
    // McGrew & Viega GCM spec, Test Case 14. We only control random nonces
    // through seal(), so verify via open() on the known ciphertext.
    final key = Uint8List(32);
    final box = SealedBox(
      Uint8List(12),
      hexDecode('cea7403d4d606b6e074ec5d3baf39d18'
          'd0d1c8a799996bf0265b98b5d48ab919'),
    );
    expect(Aead.open(key, box), Uint8List(16));
  });

  test('AES-GCM round-trips and detects tampering / wrong AAD', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i));
    final msg = Uint8List.fromList(utf8.encode('hello vault'));
    final box = Aead.seal(key, msg, associatedData: 'ctx');
    expect(Aead.open(key, box, associatedData: 'ctx'), msg);
    expect(() => Aead.open(key, box, associatedData: 'other'),
        throwsA(isA<DecryptionException>()));
    final tampered = Uint8List.fromList(box.cipherText)..[0] ^= 1;
    expect(() => Aead.open(key, SealedBox(box.nonce, tampered),
        associatedData: 'ctx'), throwsA(isA<DecryptionException>()));
  });

  test('nonces are unique per seal', () {
    final key = Uint8List(32);
    final a = Aead.seal(key, Uint8List(1));
    final b = Aead.seal(key, Uint8List(1));
    expect(hex(a.nonce), isNot(hex(b.nonce)));
  });

  test('base32 / base64url helpers', () {
    expect(utf8.decode(base32Decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ')),
        '12345678901234567890');
    expect(utf8.decode(base32Decode('jbsw y3dp')), 'Hello');
    expect(base32Encode(base32Decode('GEZDGNBVGY3TQOJQ')), 'GEZDGNBVGY3TQOJQ');
    expect(b64urlDecode(b64url([251, 255, 0])), [251, 255, 0]);
  });

  test('KDF params reject out-of-range values from a tampered header', () {
    expect(
        () => KdfParams.fromJson(
            {'alg': 'argon2id', 'm': 1, 't': 1, 'p': 1, 'salt': 'AAAA'}),
        throwsFormatException);
  });
}
