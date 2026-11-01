import 'dart:typed_data';

import '../crypto/encoding.dart';

/// A discoverable WebAuthn credential (passkey) owned by Vaultly.
/// The private key never leaves the encrypted vault.
class PasskeyCredential {
  const PasskeyCredential({
    required this.credentialId,
    required this.rpId,
    required this.rpName,
    required this.userHandle,
    required this.userName,
    required this.userDisplayName,
    required this.privateKey,
    required this.createdAt,
    this.lastUsedAt,
    this.algorithm = -7,
  });

  final Uint8List credentialId;
  final String rpId;
  final String rpName;
  final Uint8List userHandle;
  final String userName;
  final String userDisplayName;

  /// P-256 private scalar `d` (32 bytes, big-endian).
  final Uint8List privateKey;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  /// COSE algorithm identifier. -7 = ES256.
  final int algorithm;

  String get credentialIdB64 => b64url(credentialId);

  PasskeyCredential copyWith({DateTime? lastUsedAt}) => PasskeyCredential(
        credentialId: credentialId,
        rpId: rpId,
        rpName: rpName,
        userHandle: userHandle,
        userName: userName,
        userDisplayName: userDisplayName,
        privateKey: privateKey,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        algorithm: algorithm,
      );

  Map<String, dynamic> toJson() => {
        'credId': b64url(credentialId),
        'rpId': rpId,
        'rpName': rpName,
        'userHandle': b64url(userHandle),
        'userName': userName,
        'displayName': userDisplayName,
        'key': b64url(privateKey),
        'alg': algorithm,
        'created': createdAt.millisecondsSinceEpoch,
        if (lastUsedAt != null) 'lastUsed': lastUsedAt!.millisecondsSinceEpoch,
      };

  factory PasskeyCredential.fromJson(Map<String, dynamic> j) =>
      PasskeyCredential(
        credentialId: b64urlDecode(j['credId'] as String),
        rpId: j['rpId'] as String,
        rpName: j['rpName'] as String? ?? j['rpId'] as String,
        userHandle: b64urlDecode(j['userHandle'] as String),
        userName: j['userName'] as String? ?? '',
        userDisplayName: j['displayName'] as String? ?? '',
        privateKey: b64urlDecode(j['key'] as String),
        algorithm: j['alg'] as int? ?? -7,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['created'] as int),
        lastUsedAt: j['lastUsed'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(j['lastUsed'] as int),
      );
}
