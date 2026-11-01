import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../data/vault_item.dart';
import '../crypto/encoding.dart';
import '../import_export/csv_importer.dart';

/// Reads backups written by Vaultly 1.x (`iv:ciphertext`, AES-256-SIC with
/// PKCS7 padding and a key made by padding the password with `#`).
///
/// That scheme had no key stretching or authentication, which is why 2.x
/// replaced it. It is supported for import only so users can migrate.
class LegacyBackup {
  LegacyBackup._();

  static bool looksLegacy(String content) {
    final t = content.trim();
    final parts = t.split(':');
    return parts.length == 2 &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(parts[0]) &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(parts[1]);
  }

  static Uint8List _key(String password) {
    final padded = password.length >= 32
        ? password.substring(0, 32)
        : password.padRight(32, '#');
    final bytes = Uint8List.fromList(utf8.encode(padded));
    // encrypt 5.x used Key.fromUtf8 which could exceed 32 bytes for
    // non-ASCII input; AES only accepts 16/24/32, so match that length.
    if (bytes.length != 32) {
      throw const FormatException('Unsupported legacy backup password');
    }
    return bytes;
  }

  static PaddedBlockCipher _cipher(bool encrypt, Uint8List key, Uint8List iv) =>
      PaddedBlockCipher('AES/SIC/PKCS7')
        ..init(
            encrypt,
            PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
                ParametersWithIV<KeyParameter>(KeyParameter(key), iv), null));

  static List<VaultItem> decrypt(String content, String password,
      {DateTime? now}) {
    final parts = content.trim().split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid Vaultly 1.x backup');
    }
    final iv = b64Decode(parts[0]);
    final ct = b64Decode(parts[1]);
    final List<dynamic> list;
    try {
      final plain = _cipher(false, _key(password), iv).process(ct);
      list = jsonDecode(utf8.decode(plain)) as List<dynamic>;
    } catch (_) {
      throw const FormatException('Wrong password or corrupted backup');
    }
    final ts = now ?? DateTime.now();
    return [
      for (final e in list.cast<Map>())
        VaultItem(
          id: newItemId(),
          title: e['title'] as String? ?? '',
          username: e['username'] as String? ?? '',
          password: e['password'] as String? ?? '',
          createdAt: ts,
          updatedAt: e['updated_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(e['updated_at'] as int)
              : ts,
        ),
    ];
  }

  /// Produces a 1.x-format backup. Only used by tests.
  static String encryptForTest(String json, String password, Uint8List iv) {
    final ct = _cipher(true, _key(password), iv)
        .process(Uint8List.fromList(utf8.encode(json)));
    return '${b64(iv)}:${b64(ct)}';
  }
}
