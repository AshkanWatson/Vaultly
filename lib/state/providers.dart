import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/security_audit.dart';
import '../data/app_settings.dart';
import '../data/biometric_service.dart';
import '../data/favicon_service.dart';
import '../data/native_bridge.dart';
import '../data/vault_item.dart';
import '../data/vault_service.dart';

// Overridden in main() once storage is ready.
final vaultServiceProvider =
    Provider<VaultService>((ref) => throw UnimplementedError());
final initialSettingsProvider =
    Provider<AppSettings>((ref) => const AppSettings());
final vaultExistsAtStartProvider = Provider<bool>((ref) => false);
final biometricServiceProvider = Provider((ref) => BiometricService());
final faviconServiceProvider = Provider((ref) => FaviconService());

/// A passkey request from the OS, if Vaultly was launched for one.
final passkeyRequestProvider = Provider<PasskeyRequest?>((ref) => null);

final biometricKindProvider = FutureProvider<BiometricKind>(
    (ref) => ref.watch(biometricServiceProvider).availability());

// ---------------------------------------------------------------- settings --

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> update(AppSettings Function(AppSettings) f) async {
    state = f(state);
    await ref.read(vaultServiceProvider).storage.writeSettings(state.encode());
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// ------------------------------------------------------------------- vault --

enum VaultStatus { setup, locked, unlocked }

@immutable
class VaultState {
  const VaultState(this.status,
      {this.items = const [], this.generated = const []});

  final VaultStatus status;

  /// All items, including recently deleted ones.
  final List<VaultItem> items;
  final List<GeneratedPassword> generated;

  List<VaultItem> get active => items.where((i) => !i.isDeleted).toList();
  List<VaultItem> get deleted => items.where((i) => i.isDeleted).toList();
}

class VaultController extends Notifier<VaultState> {
  VaultService get _vault => ref.read(vaultServiceProvider);

  @override
  VaultState build() => VaultState(ref.read(vaultExistsAtStartProvider)
      ? VaultStatus.locked
      : VaultStatus.setup);

  void _refresh() {
    if (!_vault.isUnlocked) {
      state = const VaultState(VaultStatus.locked);
      unawaited(NativeBridge.publishPasskeyIndex(const [], unlocked: false));
      return;
    }
    final d = _vault.data;
    state = VaultState(
      VaultStatus.unlocked,
      items: List.unmodifiable(d.items),
      generated: List.unmodifiable(d.generated),
    );
    unawaited(NativeBridge.publishPasskeyIndex(state.active, unlocked: true));
  }

  Future<void> create(String masterPassword) async {
    await _vault.create(masterPassword);
    _refresh();
  }

  Future<void> unlock(String masterPassword) async {
    await _vault.unlock(masterPassword);
    _refresh();
  }

  /// Returns true when the vault was unlocked with biometrics.
  Future<bool> unlockWithBiometrics() async {
    final key = await ref.read(biometricServiceProvider).unlock();
    if (key == null) return false;
    try {
      await _vault.unlockWithKey(key);
    } catch (_) {
      // Key no longer matches (vault was erased/recreated) — forget it.
      await ref.read(biometricServiceProvider).disable();
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(biometricEnabled: false));
      return false;
    }
    _refresh();
    return true;
  }

  void lock() {
    if (state.status != VaultStatus.unlocked) return;
    _vault.lock();
    _refresh();
  }

  Future<bool> enableBiometrics() async {
    final ok = await ref.read(biometricServiceProvider).enable(_vault.vaultKey);
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(biometricEnabled: ok));
    return ok;
  }

  Future<void> disableBiometrics() async {
    await ref.read(biometricServiceProvider).disable();
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(biometricEnabled: false));
  }

  Future<VaultItem> save(VaultItem item) async {
    final saved = await _vault.save(item);
    _refresh();
    return saved;
  }

  /// Downloads the website icon for [item] in the background (if enabled,
  /// and if the item has a website but no icon yet, or its website changed).
  Future<bool> fetchIcon(VaultItem item, {bool force = false}) async {
    if (!ref.read(settingsProvider).fetchIcons) return false;
    if (item.kind != ItemKind.login || item.urls.isEmpty) return false;
    if (item.icon != null && !force) return false;
    final bytes =
        await ref.read(faviconServiceProvider).fetchForUrl(item.urls.first);
    if (bytes == null || !_vault.isUnlocked) return false;
    final current = _vault.byId(item.id);
    if (current == null || current.urls.isEmpty ||
        current.urls.first != item.urls.first) {
      return false;
    }
    await _vault.setIcon(item.id, bytes);
    _refresh();
    return true;
  }

  /// Fetches icons for every login that has a website but no icon.
  Future<int> fetchMissingIcons() async {
    var n = 0;
    for (final i in _vault.activeItems) {
      if (i.icon == null && await fetchIcon(i)) n++;
    }
    return n;
  }

  Future<void> removeAllIcons() => _run(_vault.removeAllIcons);

  Future<void> moveToTrash(String id) => _run(() => _vault.moveToTrash(id));
  Future<void> restore(String id) => _run(() => _vault.restore(id));
  Future<void> deleteForever(String id) => _run(() => _vault.deleteForever(id));
  Future<void> emptyTrash() => _run(_vault.emptyTrash);
  Future<void> toggleFavorite(String id) =>
      _run(() => _vault.toggleFavorite(id));
  Future<void> rememberGenerated(String p) =>
      _run(() => _vault.rememberGenerated(p));
  Future<void> clearGenerated() => _run(_vault.clearGenerated);

  Future<void> changeMasterPassword(String current, String next) =>
      _vault.changeMasterPassword(current, next);

  Future<bool> verifyMasterPassword(String p) =>
      _vault.verifyMasterPassword(p);

  Future<String> exportBackup(String password) => _vault.exportBackup(password);
  String exportCsv() => _vault.exportCsv();

  Future<int> importBackup(String content, String password) async {
    final n = await _vault.importBackup(content, password);
    _refresh();
    return n;
  }

  Future<({int added, int skipped, String source})> importCsv(
      String csv) async {
    final r = await _vault.importCsv(csv);
    _refresh();
    return r;
  }

  Future<(VaultItem, String)> registerPasskey(PasskeyRequest req) async {
    final r = await _vault.registerPasskey(req.requestJson,
        origin: req.origin, androidPackageName: req.packageName);
    _refresh();
    return r;
  }

  Future<String> assertPasskey(String itemId, PasskeyRequest req) async {
    final r = await _vault.assertPasskey(itemId, req.requestJson,
        origin: req.origin,
        clientDataHash: req.clientDataHash,
        androidPackageName: req.packageName);
    _refresh();
    return r;
  }

  Future<void> erase() async {
    await ref.read(biometricServiceProvider).disable();
    await _vault.erase();
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(biometricEnabled: false));
    state = const VaultState(VaultStatus.setup);
    unawaited(NativeBridge.publishPasskeyIndex(const [], unlocked: false));
  }

  Future<void> _run(Future<void> Function() f) async {
    await f();
    _refresh();
  }
}

final vaultProvider =
    NotifierProvider<VaultController, VaultState>(VaultController.new);

final securityReportProvider = Provider<SecurityReport>(
    (ref) => SecurityReport.of(ref.watch(vaultProvider).items));

// ------------------------------------------------------------- categories --

enum VaultCategory { all, passkeys, codes, wifi, security, deleted, favorites, notes }

extension VaultCategoryX on VaultCategory {
  String get title => switch (this) {
        VaultCategory.all => 'All',
        VaultCategory.passkeys => 'Passkeys',
        VaultCategory.codes => 'Codes',
        VaultCategory.wifi => 'Wi-Fi',
        VaultCategory.security => 'Security',
        VaultCategory.deleted => 'Deleted',
        VaultCategory.favorites => 'Favorites',
        VaultCategory.notes => 'Notes',
      };

  bool matches(VaultItem i) => switch (this) {
        VaultCategory.all => !i.isDeleted && i.kind == ItemKind.login,
        VaultCategory.passkeys => !i.isDeleted && i.hasPasskey,
        VaultCategory.codes => !i.isDeleted && i.hasOtp,
        VaultCategory.wifi => !i.isDeleted && i.kind == ItemKind.wifi,
        VaultCategory.deleted => i.isDeleted,
        VaultCategory.favorites => !i.isDeleted && i.favorite,
        VaultCategory.notes => !i.isDeleted && i.kind == ItemKind.note,
        VaultCategory.security => false, // computed by SecurityReport
      };
}

/// Shared search across all non-deleted items.
List<VaultItem> searchItems(Iterable<VaultItem> items, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return items.toList();
  return items.where((i) {
    return i.displayTitle.toLowerCase().contains(q) ||
        i.username.toLowerCase().contains(q) ||
        i.urls.any((u) => u.toLowerCase().contains(q)) ||
        i.notes.toLowerCase().contains(q);
  }).toList();
}
