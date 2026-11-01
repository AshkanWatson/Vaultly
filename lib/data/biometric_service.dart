import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../core/crypto/encoding.dart';

enum BiometricKind { none, faceId, touchId, fingerprint, windowsHello, generic }

extension BiometricKindLabel on BiometricKind {
  String get label => switch (this) {
        BiometricKind.faceId => 'Face ID',
        BiometricKind.touchId => 'Touch ID',
        BiometricKind.fingerprint => 'Fingerprint',
        BiometricKind.windowsHello => 'Windows Hello',
        BiometricKind.generic => 'Biometrics',
        BiometricKind.none => 'Biometrics',
      };
}

/// Biometric unlock.
///
/// The *vault key* (never the master password) is stored in the platform
/// keystore. On iOS it is bound to the current Face ID / Touch ID enrolment
/// (`biometryCurrentSet`, this-device-only), and on Android to a Keystore key
/// that requires strong biometrics, so the OS itself refuses to release it
/// without a successful scan. Enrolling a new fingerprint/face invalidates it.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;
  static const _storageKey = 'vaultly.vaultKey.v2';

  bool get _isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);
  bool get _osEnforced => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  FlutterSecureStorage get _storage => FlutterSecureStorage(
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.unlocked_this_device,
          accessControlFlags: [AccessControlFlag.biometryCurrentSet],
          synchronizable: false,
        ),
        mOptions: const MacOsOptions(
          accessibility: KeychainAccessibility.unlocked_this_device,
          synchronizable: false,
        ),
        aOptions: const AndroidOptions.biometric(
          enforceBiometrics: true,
          biometricType: AndroidBiometricType.strongBiometricOnly,
          biometricPromptTitle: 'Unlock Vaultly',
          biometricPromptSubtitle: 'Confirm it’s you to open your vault',
          biometricPromptNegativeButton: 'Use Password',
        ),
      );

  Future<BiometricKind> availability() async {
    if (kIsWeb || Platform.isLinux) return BiometricKind.none;
    try {
      if (!await _auth.isDeviceSupported()) return BiometricKind.none;
      if (Platform.isWindows) return BiometricKind.windowsHello;
      final types = await _auth.getAvailableBiometrics();
      if (types.isEmpty) return BiometricKind.none;
      if (types.contains(BiometricType.face)) {
        return _isApple ? BiometricKind.faceId : BiometricKind.generic;
      }
      if (types.contains(BiometricType.fingerprint)) {
        return _isApple ? BiometricKind.touchId : BiometricKind.fingerprint;
      }
      return BiometricKind.generic;
    } on PlatformException {
      return BiometricKind.none;
    } on MissingPluginException {
      return BiometricKind.none;
    }
  }

  Future<bool> _prompt(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: !Platform.isWindows,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Stores [vaultKey] behind biometrics after the user confirms.
  Future<bool> enable(Uint8List vaultKey) async {
    if (!await _prompt('Turn on biometric unlock for Vaultly')) return false;
    try {
      await _storage.write(key: _storageKey, value: b64(vaultKey));
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Releases the vault key after a biometric check, or null if cancelled,
  /// unavailable or invalidated (e.g. a new fingerprint was enrolled).
  Future<Uint8List?> unlock() async {
    try {
      if (!_osEnforced && !await _prompt('Unlock your vault')) return null;
      final v = await _storage.read(key: _storageKey);
      return v == null ? null : b64Decode(v);
    } on PlatformException {
      return null;
    }
  }

  Future<void> disable() async {
    try {
      await _storage.delete(key: _storageKey);
    } on PlatformException {
      // Nothing stored.
    }
  }
}
