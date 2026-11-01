import 'dart:convert';
import 'dart:typed_data';

import '../core/crypto/aead.dart';
import '../core/crypto/encoding.dart';
import '../core/crypto/kdf.dart';
import '../core/crypto/secure_random.dart';
import 'vault_item.dart';

class WrongPasswordException implements Exception {
  const WrongPasswordException();
  @override
  String toString() => 'Incorrect password';
}

class VaultFormatException implements Exception {
  const VaultFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What an envelope protects. Bound into the AES-GCM associated data so a
/// backup file can never be mistaken for (or swapped in as) the live vault.
enum EnvelopeKind { vault, backup }

/// On-disk vault format (version 2).
///
/// ```text
/// master password ──Argon2id(salt)──▶ KEK
/// KEK  ──AES-256-GCM──▶ keyBox  (random 256-bit vault key)
/// vault key ──AES-256-GCM──▶ dataBox (JSON payload)
/// ```
///
/// A random vault key means the master password can be changed by re-wrapping
/// 32 bytes, and biometric unlock can store the vault key in the Secure
/// Enclave / Android Keystore without the master password ever being saved.
class VaultEnvelope {
  const VaultEnvelope({
    required this.kind,
    required this.kdf,
    required this.keyBox,
    required this.dataBox,
  });

  static const String formatId = 'vaultly';
  static const int formatVersion = 2;

  final EnvelopeKind kind;
  final KdfParams kdf;
  final SealedBox keyBox;
  final SealedBox dataBox;

  String get _keyAad => '$formatId/$formatVersion/${kind.name}/key';
  String get _dataAad => '$formatId/$formatVersion/${kind.name}/data';

  /// Creates a new envelope with a fresh vault key. Returns the envelope and
  /// the (unwrapped) vault key.
  static Future<(VaultEnvelope, Uint8List)> create(
    String password,
    VaultData data, {
    EnvelopeKind kind = EnvelopeKind.vault,
    KdfParams? kdf,
  }) async {
    final params = kdf ?? KdfParams.generate();
    final kek = await deriveKey(password, params);
    final vaultKey = SecureRandomSource.bytes(32);
    try {
      final env = VaultEnvelope(
        kind: kind,
        kdf: params,
        keyBox: Aead.seal(kek, vaultKey,
            associatedData: '$formatId/$formatVersion/${kind.name}/key'),
        dataBox: SealedBox(Uint8List(0), Uint8List(0)),
      ).withData(vaultKey, data);
      return (env, vaultKey);
    } finally {
      wipe(kek);
    }
  }

  /// Unwraps the vault key. Throws [WrongPasswordException] on failure.
  Future<Uint8List> unlock(String password) async {
    final kek = await deriveKey(password, kdf);
    try {
      return Aead.open(kek, keyBox, associatedData: _keyAad);
    } on DecryptionException {
      throw const WrongPasswordException();
    } finally {
      wipe(kek);
    }
  }

  VaultData decrypt(Uint8List vaultKey) {
    try {
      final plain = Aead.open(vaultKey, dataBox, associatedData: _dataAad);
      return VaultData.fromJson(
          jsonDecode(utf8.decode(plain)) as Map<String, dynamic>);
    } on DecryptionException {
      throw const WrongPasswordException();
    }
  }

  /// Re-encrypts [data] with a fresh nonce.
  VaultEnvelope withData(Uint8List vaultKey, VaultData data) => VaultEnvelope(
        kind: kind,
        kdf: kdf,
        keyBox: keyBox,
        dataBox: Aead.seal(
            vaultKey, Uint8List.fromList(utf8.encode(jsonEncode(data))),
            associatedData: _dataAad),
      );

  /// Re-wraps the vault key under a new master password (new salt too).
  Future<VaultEnvelope> rewrap(Uint8List vaultKey, String newPassword) async {
    final params = KdfParams.generate(
      memoryKiB: KdfParams.defaultMemoryKiB,
      iterations: KdfParams.defaultIterations,
      parallelism: KdfParams.defaultParallelism,
    );
    final kek = await deriveKey(newPassword, params);
    try {
      return VaultEnvelope(
        kind: kind,
        kdf: params,
        keyBox: Aead.seal(kek, vaultKey, associatedData: _keyAad),
        dataBox: dataBox,
      );
    } finally {
      wipe(kek);
    }
  }

  String encode() => const JsonEncoder.withIndent(' ').convert({
        'format': formatId,
        'version': formatVersion,
        'kind': kind.name,
        'kdf': kdf.toJson(),
        'key': keyBox.toJson(),
        'data': dataBox.toJson(),
      });

  static bool looksLikeEnvelope(String text) {
    final t = text.trimLeft();
    return t.startsWith('{') && t.contains('"format"') && t.contains(formatId);
  }

  static VaultEnvelope decode(String text, {EnvelopeKind? expect}) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['format'] != formatId) {
        throw const VaultFormatException('Not a Vaultly file');
      }
      if (j['version'] != formatVersion) {
        throw VaultFormatException(
            'Unsupported Vaultly file version ${j['version']}');
      }
      final kind = EnvelopeKind.values.firstWhere((k) => k.name == j['kind'],
          orElse: () => throw const VaultFormatException('Unknown file kind'));
      if (expect != null && kind != expect) {
        throw VaultFormatException(kind == EnvelopeKind.vault
            ? 'This is a vault file, not a backup'
            : 'This is a backup file, not a vault');
      }
      return VaultEnvelope(
        kind: kind,
        kdf: KdfParams.fromJson(j['kdf'] as Map<String, dynamic>),
        keyBox: SealedBox.fromJson(j['key'] as Map<String, dynamic>),
        dataBox: SealedBox.fromJson(j['data'] as Map<String, dynamic>),
      );
    } on VaultFormatException {
      rethrow;
    } on FormatException catch (e) {
      throw VaultFormatException('Corrupted Vaultly file (${e.message})');
    } on TypeError {
      throw const VaultFormatException('Corrupted Vaultly file');
    }
  }
}
