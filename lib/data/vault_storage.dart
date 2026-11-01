import 'dart:io';

import 'package:path/path.dart' as p;

/// Local file storage for the encrypted vault. Writes are atomic
/// (write temp file → fsync → rename) and the previous version is kept as
/// `vault.vaultly.bak` so a crash or full disk can never corrupt the vault.
class VaultStorage {
  VaultStorage(this.directory);

  final Directory directory;

  File get vaultFile => File(p.join(directory.path, 'vault.vaultly'));
  File get backupFile => File(p.join(directory.path, 'vault.vaultly.bak'));
  File get settingsFile => File(p.join(directory.path, 'settings.json'));

  Future<void> _ensureDir() async {
    if (!await directory.exists()) await directory.create(recursive: true);
  }

  Future<bool> hasVault() => vaultFile.exists();

  Future<String?> readVault() async {
    if (await vaultFile.exists()) return vaultFile.readAsString();
    // Recover from an interrupted rename.
    if (await backupFile.exists()) return backupFile.readAsString();
    return null;
  }

  Future<void> writeVault(String contents) async {
    await _ensureDir();
    final tmp = File('${vaultFile.path}.tmp');
    final raf = await tmp.open(mode: FileMode.writeOnly);
    try {
      await raf.writeString(contents);
      await raf.flush();
    } finally {
      await raf.close();
    }
    if (await vaultFile.exists()) {
      if (await backupFile.exists()) await backupFile.delete();
      await vaultFile.rename(backupFile.path);
    }
    await tmp.rename(vaultFile.path);
  }

  Future<String?> readSettings() async =>
      await settingsFile.exists() ? settingsFile.readAsString() : null;

  Future<void> writeSettings(String contents) async {
    await _ensureDir();
    final tmp = File('${settingsFile.path}.tmp');
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(settingsFile.path);
  }

  /// Permanently deletes the vault (used by "Erase Vault").
  Future<void> erase() async {
    for (final f in [
      vaultFile,
      backupFile,
      File('${vaultFile.path}.tmp'),
    ]) {
      if (await f.exists()) await f.delete();
    }
  }
}
