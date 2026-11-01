import 'dart:async';
import 'dart:typed_data';

import '../core/crypto/encoding.dart';
import '../core/import_export/csv_importer.dart';
import '../core/import_export/legacy_backup.dart';
import '../core/passkey/passkey_credential.dart';
import '../core/passkey/webauthn.dart';
import 'vault_envelope.dart';
import 'vault_item.dart';
import 'vault_storage.dart';

class VaultLockedException implements Exception {
  const VaultLockedException();
  @override
  String toString() => 'The vault is locked';
}

/// Owns the decrypted vault while unlocked. Pure Dart (no Flutter), so all
/// behaviour is covered by unit tests.
class VaultService {
  VaultService(this.storage);

  final VaultStorage storage;

  static const trashRetention = Duration(days: 30);
  static const maxPasswordHistory = 10;
  static const maxGeneratedHistory = 30;

  VaultEnvelope? _envelope;
  Uint8List? _key;
  VaultData? _data;
  Future<void> _writeQueue = Future.value();

  bool get isUnlocked => _key != null && _data != null;

  VaultData get data => _data ?? (throw const VaultLockedException());

  /// A copy of the vault key, for storing behind biometrics.
  Uint8List get vaultKey =>
      Uint8List.fromList(_key ?? (throw const VaultLockedException()));

  Future<bool> exists() => storage.hasVault();

  // ------------------------------------------------------------ lifecycle --

  Future<void> create(String masterPassword) async {
    final (env, key) = await VaultEnvelope.create(masterPassword, VaultData());
    _envelope = env;
    _key = key;
    _data = VaultData();
    await _persist();
  }

  Future<VaultEnvelope> _load() async {
    final text = await storage.readVault();
    if (text == null) throw const VaultFormatException('No vault found');
    return VaultEnvelope.decode(text, expect: EnvelopeKind.vault);
  }

  Future<void> unlock(String masterPassword) async {
    final env = await _load();
    final key = await env.unlock(masterPassword);
    _open(env, key);
  }

  /// Unlocks with a vault key released by biometrics.
  Future<void> unlockWithKey(Uint8List key) async {
    final env = await _load();
    _open(env, Uint8List.fromList(key));
  }

  void _open(VaultEnvelope env, Uint8List key) {
    final data = env.decrypt(key);
    _envelope = env;
    _key = key;
    _data = data;
    _purgeExpiredTrash();
  }

  Future<bool> verifyMasterPassword(String password) async {
    try {
      final k = await (await _load()).unlock(password);
      wipe(k);
      return true;
    } on WrongPasswordException {
      return false;
    }
  }

  void lock() {
    wipe(_key);
    _key = null;
    _data = null;
    _envelope = null;
  }

  Future<void> changeMasterPassword(String current, String next) async {
    if (!isUnlocked) throw const VaultLockedException();
    if (!await verifyMasterPassword(current)) {
      throw const WrongPasswordException();
    }
    _envelope = await _envelope!.rewrap(_key!, next);
    await _persist();
  }

  Future<void> erase() async {
    lock();
    await storage.erase();
  }

  // ---------------------------------------------------------------- items --

  List<VaultItem> get activeItems =>
      data.items.where((i) => !i.isDeleted).toList();

  VaultItem? byId(String id) {
    for (final i in data.items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Inserts or updates [item], recording password history on change.
  Future<VaultItem> save(VaultItem item, {DateTime? now}) async {
    final ts = now ?? DateTime.now();
    final items = data.items;
    final idx = items.indexWhere((i) => i.id == item.id);
    var toSave = item.copyWith(updatedAt: ts);
    if (idx >= 0) {
      final old = items[idx];
      if (old.password.isNotEmpty && old.password != item.password) {
        toSave = toSave.copyWith(passwordHistory: [
          PasswordHistoryEntry(old.password, ts),
          ...old.passwordHistory,
        ].take(maxPasswordHistory).toList());
      }
      items[idx] = toSave;
    } else {
      items.add(toSave);
    }
    await _persist();
    return toSave;
  }

  Future<void> moveToTrash(String id) =>
      _update(id, (i) => i.copyWith(deletedAt: DateTime.now()));

  Future<void> restore(String id) =>
      _update(id, (i) => i.copyWith(restore: true));

  Future<void> toggleFavorite(String id) =>
      _update(id, (i) => i.copyWith(favorite: !i.favorite));

  Future<void> deleteForever(String id) async {
    data.items.removeWhere((i) => i.id == id);
    await _persist();
  }

  Future<void> emptyTrash() async {
    data.items.removeWhere((i) => i.isDeleted);
    await _persist();
  }

  /// Stores a website icon. Doesn't change "last modified".
  Future<void> setIcon(String id, Uint8List icon) async {
    final idx = data.items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    data.items[idx] = data.items[idx].copyWith(icon: icon);
    await _persist();
  }

  Future<void> removeAllIcons() async {
    for (var i = 0; i < data.items.length; i++) {
      if (data.items[i].icon != null) {
        data.items[i] = data.items[i].copyWith(clearIcon: true);
      }
    }
    await _persist();
  }

  Future<void> _update(String id, VaultItem Function(VaultItem) f) async {
    final idx = data.items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    data.items[idx] = f(data.items[idx]).copyWith(updatedAt: DateTime.now());
    await _persist();
  }

  void _purgeExpiredTrash() {
    final cutoff = DateTime.now().subtract(trashRetention);
    final before = data.items.length;
    data.items.removeWhere(
        (i) => i.deletedAt != null && i.deletedAt!.isBefore(cutoff));
    if (data.items.length != before) unawaited(_persist());
  }

  // -------------------------------------------------- generator history --

  Future<void> rememberGenerated(String password) async {
    if (data.generated.isNotEmpty && data.generated.first.value == password) {
      return;
    }
    data.generated.insert(0, GeneratedPassword(password, DateTime.now()));
    if (data.generated.length > maxGeneratedHistory) {
      data.generated.removeRange(maxGeneratedHistory, data.generated.length);
    }
    await _persist();
  }

  Future<void> clearGenerated() async {
    data.generated.clear();
    await _persist();
  }

  // ------------------------------------------------------ import / export --

  /// Encrypted, portable backup protected by its own password.
  Future<String> exportBackup(String backupPassword) async {
    final (env, key) = await VaultEnvelope.create(
      backupPassword,
      VaultData(items: activeItems),
      kind: EnvelopeKind.backup,
    );
    wipe(key);
    return env.encode();
  }

  /// Imports a Vaultly backup (2.x or 1.x). Returns how many items were
  /// added or updated.
  Future<int> importBackup(String content, String backupPassword) async {
    final List<VaultItem> incoming;
    if (VaultEnvelope.looksLikeEnvelope(content)) {
      final env = VaultEnvelope.decode(content);
      final key = await env.unlock(backupPassword);
      try {
        incoming = env.decrypt(key).items;
      } finally {
        wipe(key);
      }
    } else if (LegacyBackup.looksLegacy(content)) {
      incoming = LegacyBackup.decrypt(content, backupPassword);
    } else {
      throw const VaultFormatException('This is not a Vaultly backup file');
    }
    return mergeItems(incoming);
  }

  Future<({int added, int skipped, String source})> importCsv(
      String csv) async {
    final result = CsvImporter.parse(csv);
    final added = await mergeItems(result.items);
    return (
      added: added,
      skipped: result.skipped + result.items.length - added,
      source: result.source,
    );
  }

  String exportCsv() => CsvImporter.export(activeItems);

  /// Adds [incoming] items: same id → newest wins; identical entries are
  /// skipped so importing the same file twice creates no duplicates.
  Future<int> mergeItems(List<VaultItem> incoming) async {
    var changed = 0;
    for (final item in incoming) {
      final idx = data.items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        if (item.updatedAt.isAfter(data.items[idx].updatedAt)) {
          data.items[idx] = item;
          changed++;
        }
        continue;
      }
      final dup = data.items.any((i) =>
          !i.isDeleted &&
          i.displayTitle.toLowerCase() == item.displayTitle.toLowerCase() &&
          i.username == item.username &&
          i.password == item.password);
      if (!dup) {
        data.items.add(item);
        changed++;
      }
    }
    if (changed > 0) await _persist();
    return changed;
  }

  // ------------------------------------------------------------- passkeys --

  Iterable<VaultItem> passkeyItemsFor(String rpId) => activeItems
      .where((i) => i.passkey != null && i.passkey!.rpId == rpId);

  /// Creates a passkey for a WebAuthn registration request. If a login for
  /// the same site and user exists, the passkey is attached to it (like
  /// Apple Passwords); otherwise a new item is created.
  Future<(VaultItem, String)> registerPasskey(
    String requestJson, {
    required String origin,
    String? androidPackageName,
  }) async {
    final req = CreationRequest.fromJson(requestJson);
    final existing = activeItems
        .map((i) => i.passkey)
        .whereType<PasskeyCredential>();
    final (cred, response) = WebAuthnAuthenticator.register(
      req,
      origin: origin,
      androidPackageName: androidPackageName,
      existing: existing,
    );
    final now = DateTime.now();
    final match = activeItems.where((i) =>
        i.passkey == null &&
        i.username == req.userName &&
        i.hosts.any((h) => h == req.rpId || h.endsWith('.${req.rpId}')));
    final VaultItem saved;
    if (match.isNotEmpty) {
      saved = await save(match.first.copyWith(passkey: cred));
    } else {
      saved = await save(VaultItem(
        id: newItemId(),
        title: req.rpName,
        username: req.userName,
        urls: ['https://${req.rpId}'],
        passkey: cred,
        createdAt: now,
        updatedAt: now,
      ));
    }
    return (saved, response);
  }

  /// Signs a WebAuthn assertion with the passkey stored in [itemId].
  Future<String> assertPasskey(
    String itemId,
    String requestJson, {
    required String origin,
    Uint8List? clientDataHash,
    String? androidPackageName,
  }) async {
    final item = byId(itemId);
    final cred = item?.passkey;
    if (item == null || cred == null) {
      throw const WebAuthnException('NotAllowedError', 'Passkey not found');
    }
    final response = WebAuthnAuthenticator.assertion(
      cred,
      AssertionRequest.fromJson(requestJson),
      origin: origin,
      clientDataHash: clientDataHash,
      androidPackageName: androidPackageName,
    );
    final idx = data.items.indexWhere((i) => i.id == itemId);
    data.items[idx] =
        item.copyWith(passkey: cred.copyWith(lastUsedAt: DateTime.now()));
    await _persist();
    return response;
  }

  // ---------------------------------------------------------- persistence --

  Future<void> _persist() {
    final env = _envelope;
    final key = _key;
    final d = _data;
    if (env == null || key == null || d == null) {
      return Future.error(const VaultLockedException());
    }
    _envelope = env.withData(key, d);
    final text = _envelope!.encode();
    // Serialise writes so renames never race each other.
    return _writeQueue = _writeQueue
        .catchError((Object _) {})
        .then((_) => storage.writeVault(text));
  }
}
