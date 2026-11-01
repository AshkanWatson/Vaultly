import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/crypto/encoding.dart';
import 'vault_item.dart';

/// A pending passkey request handed to Vaultly by the OS passkey provider
/// API (Android Credential Manager).
class PasskeyRequest {
  PasskeyRequest({
    required this.type,
    required this.requestJson,
    required this.origin,
    this.packageName,
    this.clientDataHash,
    this.itemId,
  });

  /// `create`, `get` or `unlock`.
  final String type;
  final String requestJson;
  final String origin;
  final String? packageName;
  final Uint8List? clientDataHash;
  final String? itemId;

  static PasskeyRequest? fromMap(Map<Object?, Object?>? m) {
    if (m == null) return null;
    final hash = m['clientDataHash'] as String?;
    return PasskeyRequest(
      type: m['type'] as String,
      requestJson: m['requestJson'] as String? ?? '{}',
      origin: m['origin'] as String? ?? '',
      packageName: m['packageName'] as String?,
      clientDataHash: hash == null ? null : b64urlDecode(hash),
      itemId: m['itemId'] as String?,
    );
  }
}

/// Talks to the small amount of native code Vaultly ships
/// (`MainActivity.kt` / `PasskeyActivity.kt` / `AppDelegate.swift`).
class NativeBridge {
  NativeBridge._();

  static const _channel = MethodChannel('app.vaultly/native');

  static bool get _android => !kIsWeb && Platform.isAndroid;

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Copies [text], flagging it as sensitive on Android 13+ so it is hidden
  /// from the clipboard preview and keyboard suggestions.
  static Future<void> copySensitive(String text) async {
    if (_android && await _call<bool>('copySensitive', text) == true) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> clearClipboardIfUnchanged(String copied) async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == copied) {
      if (_android) {
        await _call<bool>('clearClipboard');
      } else {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    }
  }

  // ------------------------------------------------------- passkeys ----

  static Future<PasskeyRequest?> pendingPasskeyRequest() async {
    if (!_android) return null;
    return PasskeyRequest.fromMap(
        await _call<Map<Object?, Object?>>('passkey.pendingRequest'));
  }

  /// Shares *metadata only* (no keys) of passkeys with the Android provider
  /// service while the vault is unlocked so it can list them in the system
  /// sheet. Cleared on lock.
  static Future<void> publishPasskeyIndex(Iterable<VaultItem> items,
      {required bool unlocked}) async {
    if (!_android) return;
    await _call<void>('passkey.updateIndex', {
      'unlocked': unlocked,
      'items': [
        for (final i in items)
          if (i.passkey != null && !i.isDeleted)
            {
              'itemId': i.id,
              'rpId': i.passkey!.rpId,
              'userName': i.passkey!.userName,
              'displayName': i.passkey!.userDisplayName.isEmpty
                  ? i.displayTitle
                  : i.passkey!.userDisplayName,
              'credentialId': i.passkey!.credentialIdB64,
              'lastUsed': i.passkey!.lastUsedAt?.millisecondsSinceEpoch,
            },
      ],
    });
  }

  static Future<void> completePasskeyRequest(String responseJson) =>
      _call<void>('passkey.complete', responseJson);

  static Future<void> completeUnlock() => _call<void>('passkey.unlocked');

  static Future<void> cancelPasskeyRequest([String? error]) =>
      _call<void>('passkey.cancel', error);

  /// Opens the system screen where the user picks Vaultly as their passkey
  /// provider (Android 14+). Returns false if not supported.
  static Future<bool> openPasskeyProviderSettings() async =>
      await _call<bool>('passkey.openSettings') ?? false;
}
