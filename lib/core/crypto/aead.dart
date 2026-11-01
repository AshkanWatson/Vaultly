import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'encoding.dart';
import 'secure_random.dart';

/// Thrown when authenticated decryption fails (wrong key or tampered data).
class DecryptionException implements Exception {
  const DecryptionException([this.message = 'Decryption failed']);
  final String message;
  @override
  String toString() => message;
}

/// AES-256-GCM ciphertext together with its unique 96-bit nonce.
/// `cipherText` contains the 16-byte authentication tag at the end, which is
/// the same layout CryptoKit (`AES.GCM.SealedBox.combined`) and
/// `javax.crypto` use, so native code can open these boxes directly.
class SealedBox {
  const SealedBox(this.nonce, this.cipherText);

  final Uint8List nonce;
  final Uint8List cipherText;

  Map<String, dynamic> toJson() => {'n': b64(nonce), 'c': b64(cipherText)};

  factory SealedBox.fromJson(Map<String, dynamic> json) => SealedBox(
        b64Decode(json['n'] as String),
        b64Decode(json['c'] as String),
      );
}

class Aead {
  Aead._();

  static const int keyLength = 32;
  static const int nonceLength = 12;
  static const int tagBits = 128;

  static SealedBox seal(Uint8List key, Uint8List plainText,
      {String associatedData = ''}) {
    _checkKey(key);
    final nonce = SecureRandomSource.bytes(nonceLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          true,
          AEADParameters(KeyParameter(key), tagBits, nonce,
              Uint8List.fromList(utf8.encode(associatedData))));
    return SealedBox(nonce, cipher.process(plainText));
  }

  static Uint8List open(Uint8List key, SealedBox box,
      {String associatedData = ''}) {
    _checkKey(key);
    if (box.nonce.length != nonceLength) {
      throw const DecryptionException('Invalid nonce');
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          false,
          AEADParameters(KeyParameter(key), tagBits, box.nonce,
              Uint8List.fromList(utf8.encode(associatedData))));
    try {
      return cipher.process(box.cipherText);
    } on InvalidCipherTextException {
      throw const DecryptionException();
    } on ArgumentError {
      throw const DecryptionException();
    }
  }

  static void _checkKey(Uint8List key) {
    if (key.length != keyLength) {
      throw ArgumentError('AES-256 key must be 32 bytes');
    }
  }
}
