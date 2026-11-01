import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../crypto/encoding.dart';
import '../crypto/secure_random.dart';
import 'cbor.dart';
import 'passkey_credential.dart';

class WebAuthnException implements Exception {
  const WebAuthnException(this.name, this.message);

  /// DOMException name the platform should surface (e.g. `NotSupportedError`).
  final String name;
  final String message;
  @override
  String toString() => '$name: $message';
}

/// Parsed `PublicKeyCredentialCreationOptionsJSON`.
class CreationRequest {
  CreationRequest({
    required this.rpId,
    required this.rpName,
    required this.userHandle,
    required this.userName,
    required this.userDisplayName,
    required this.challenge,
    required this.algorithms,
    required this.excludeCredentialIds,
  });

  final String rpId;
  final String rpName;
  final Uint8List userHandle;
  final String userName;
  final String userDisplayName;

  /// base64url challenge exactly as received.
  final String challenge;
  final List<int> algorithms;
  final List<String> excludeCredentialIds;

  factory CreationRequest.fromJson(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final rp = (j['rp'] as Map).cast<String, dynamic>();
    final user = (j['user'] as Map).cast<String, dynamic>();
    final rpId = rp['id'] as String?;
    if (rpId == null || rpId.isEmpty) {
      throw const WebAuthnException('SecurityError', 'Missing rp.id');
    }
    return CreationRequest(
      rpId: rpId,
      rpName: rp['name'] as String? ?? rpId,
      userHandle: b64urlDecode(user['id'] as String),
      userName: user['name'] as String? ?? '',
      userDisplayName: user['displayName'] as String? ?? '',
      challenge: j['challenge'] as String,
      algorithms: ((j['pubKeyCredParams'] as List?) ?? const [])
          .map((e) => (e as Map)['alg'] as int)
          .toList(),
      excludeCredentialIds: ((j['excludeCredentials'] as List?) ?? const [])
          .map((e) => (e as Map)['id'] as String)
          .toList(),
    );
  }
}

/// Parsed `PublicKeyCredentialRequestOptionsJSON`.
class AssertionRequest {
  AssertionRequest({
    required this.rpId,
    required this.challenge,
    required this.allowCredentialIds,
  });

  final String rpId;
  final String challenge;
  final List<String> allowCredentialIds;

  factory AssertionRequest.fromJson(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    return AssertionRequest(
      rpId: j['rpId'] as String,
      challenge: j['challenge'] as String,
      allowCredentialIds: ((j['allowCredentials'] as List?) ?? const [])
          .map((e) => (e as Map)['id'] as String)
          .toList(),
    );
  }

  bool allows(PasskeyCredential c) =>
      c.rpId == rpId &&
      (allowCredentialIds.isEmpty ||
          allowCredentialIds.contains(c.credentialIdB64));
}

/// A software WebAuthn authenticator (ES256, "none" attestation).
///
/// The OS passkey provider APIs (Android Credential Manager, iOS
/// AuthenticationServices) hand us request JSON and expect response JSON
/// back; everything in between happens here, in tested Dart code.
class WebAuthnAuthenticator {
  WebAuthnAuthenticator._();

  /// Vaultly's authenticator AAGUID (lets websites show "Vaultly" as the
  /// passkey provider).
  static final Uint8List aaguid =
      hexDecode('7a1c4f2e9b3d4e6a8c5f0d2b7e9a1c3f');

  static const int flagUserPresent = 0x01;
  static const int flagUserVerified = 0x04;
  static const int flagBackupEligible = 0x08;
  static const int flagAttestedData = 0x40;

  static const int es256 = -7;

  static final ECDomainParameters _p256 = ECDomainParameters('secp256r1');

  // ---------------------------------------------------------------- keys --

  static PasskeyCredential createCredential({
    required String rpId,
    required String rpName,
    required Uint8List userHandle,
    required String userName,
    required String userDisplayName,
    DateTime? now,
  }) {
    final gen = ECKeyGenerator()
      ..init(ParametersWithRandom(
          ECKeyGeneratorParameters(_p256), SecureRandomSource.pointyCastle()));
    final pair = gen.generateKeyPair();
    final priv = pair.privateKey;
    return PasskeyCredential(
      credentialId: SecureRandomSource.bytes(16),
      rpId: rpId,
      rpName: rpName,
      userHandle: userHandle,
      userName: userName,
      userDisplayName: userDisplayName,
      privateKey: _bigIntToBytes(priv.d!, 32),
      createdAt: now ?? DateTime.now(),
    );
  }

  static ECPublicKey publicKeyOf(PasskeyCredential c) {
    final d = _bytesToBigInt(c.privateKey);
    return ECPublicKey(_p256.G * d, _p256);
  }

  static (Uint8List x, Uint8List y) publicCoordinates(PasskeyCredential c) {
    final q = publicKeyOf(c).Q!;
    return (
      _bigIntToBytes(q.x!.toBigInteger()!, 32),
      _bigIntToBytes(q.y!.toBigInteger()!, 32),
    );
  }

  /// COSE_Key (RFC 9053) for an EC2 P-256 public key.
  static Uint8List coseKey(PasskeyCredential c) {
    final (x, y) = publicCoordinates(c);
    return Cbor.encode({1: 2, 3: es256, -1: 1, -2: x, -3: y});
  }

  /// X.509 SubjectPublicKeyInfo (DER) for the public key.
  static Uint8List spki(PasskeyCredential c) {
    final (x, y) = publicCoordinates(c);
    return Uint8List.fromList([
      ...hexDecode('3059301306072a8648ce3d020106082a8648ce3d030107034200'),
      0x04,
      ...x,
      ...y,
    ]);
  }

  // ------------------------------------------------------- authenticator --

  static Uint8List authenticatorData({
    required String rpId,
    required int flags,
    int signCount = 0,
    PasskeyCredential? attested,
  }) {
    final b = BytesBuilder(copy: false)
      ..add(SHA256Digest().process(Uint8List.fromList(utf8.encode(rpId))))
      ..addByte(flags | (attested != null ? flagAttestedData : 0))
      ..add([
        (signCount >> 24) & 0xff,
        (signCount >> 16) & 0xff,
        (signCount >> 8) & 0xff,
        signCount & 0xff,
      ]);
    if (attested != null) {
      final id = attested.credentialId;
      b
        ..add(aaguid)
        ..add([(id.length >> 8) & 0xff, id.length & 0xff])
        ..add(id)
        ..add(coseKey(attested));
    }
    return b.toBytes();
  }

  /// ES256 signature (ASN.1 DER, low-S) over `authData || clientDataHash`.
  static Uint8List sign(
      PasskeyCredential c, Uint8List authData, Uint8List clientDataHash) {
    final signer = ECDSASigner(SHA256Digest(), HMac(SHA256Digest(), 64))
      ..init(
          true,
          PrivateKeyParameter<ECPrivateKey>(
              ECPrivateKey(_bytesToBigInt(c.privateKey), _p256)));
    final msg = Uint8List.fromList([...authData, ...clientDataHash]);
    final sig = signer.generateSignature(msg) as ECSignature;
    final n = _p256.n;
    final s = sig.s > (n >> 1) ? n - sig.s : sig.s;
    return _derSignature(sig.r, s);
  }

  static bool verify(ECPublicKey key, Uint8List message, Uint8List der) {
    final (r, s) = _parseDer(der);
    final v = ECDSASigner(SHA256Digest())
      ..init(false, PublicKeyParameter<ECPublicKey>(key));
    return v.verifySignature(message, ECSignature(r, s));
  }

  /// `CollectedClientData` JSON, with members in the order browsers use.
  static String clientDataJson({
    required String type,
    required String challenge,
    required String origin,
    String? androidPackageName,
  }) =>
      jsonEncode({
        'type': type,
        'challenge': challenge,
        'origin': origin,
        'crossOrigin': false,
        'androidPackageName': ?androidPackageName,
      });

  // ------------------------------------------------------ high-level API --

  /// Handles a registration ceremony. Returns the new credential (to be
  /// saved in the vault) and the `RegistrationResponseJSON` for the platform.
  ///
  /// "none" attestation carries no signature, so unlike [assertion] no
  /// clientDataHash is needed; browsers replace clientDataJSON with their own.
  static (PasskeyCredential, String) register(
    CreationRequest req, {
    required String origin,
    String? androidPackageName,
    Iterable<PasskeyCredential> existing = const [],
  }) {
    if (req.algorithms.isNotEmpty && !req.algorithms.contains(es256)) {
      throw const WebAuthnException(
          'NotSupportedError', 'Vaultly passkeys use ES256 (P-256)');
    }
    final excluded = existing.any((c) =>
        c.rpId == req.rpId &&
        req.excludeCredentialIds.contains(c.credentialIdB64));
    if (excluded) {
      throw const WebAuthnException('InvalidStateError',
          'A passkey for this account is already saved in Vaultly');
    }

    final cred = createCredential(
      rpId: req.rpId,
      rpName: req.rpName,
      userHandle: req.userHandle,
      userName: req.userName,
      userDisplayName: req.userDisplayName,
    );
    final authData = authenticatorData(
      rpId: req.rpId,
      flags: flagUserPresent | flagUserVerified | flagBackupEligible,
      attested: cred,
    );
    final attObj = Cbor.encode({
      'fmt': 'none',
      'attStmt': <String, Object?>{},
      'authData': authData,
    });
    final clientData = clientDataJson(
      type: 'webauthn.create',
      challenge: req.challenge,
      origin: origin,
      androidPackageName: androidPackageName,
    );
    final id = b64url(cred.credentialId);
    final response = {
      'id': id,
      'rawId': id,
      'type': 'public-key',
      'authenticatorAttachment': 'platform',
      'response': {
        'clientDataJSON': b64url(utf8.encode(clientData)),
        'attestationObject': b64url(attObj),
        'authenticatorData': b64url(authData),
        'transports': ['internal', 'hybrid'],
        'publicKey': b64url(spki(cred)),
        'publicKeyAlgorithm': es256,
      },
      'clientExtensionResults': {
        'credProps': {'rk': true},
      },
    };
    return (cred, jsonEncode(response));
  }

  /// Handles an authentication ceremony and returns
  /// `AuthenticationResponseJSON`.
  static String assertion(
    PasskeyCredential cred,
    AssertionRequest req, {
    required String origin,
    Uint8List? clientDataHash,
    String? androidPackageName,
  }) {
    if (!req.allows(cred)) {
      throw const WebAuthnException(
          'NotAllowedError', 'Passkey not valid for this request');
    }
    final authData = authenticatorData(
      rpId: req.rpId,
      flags: flagUserPresent | flagUserVerified | flagBackupEligible,
    );
    final clientData = clientDataJson(
      type: 'webauthn.get',
      challenge: req.challenge,
      origin: origin,
      androidPackageName: androidPackageName,
    );
    final hash = clientDataHash ??
        SHA256Digest().process(Uint8List.fromList(utf8.encode(clientData)));
    final id = b64url(cred.credentialId);
    return jsonEncode({
      'id': id,
      'rawId': id,
      'type': 'public-key',
      'authenticatorAttachment': 'platform',
      'response': {
        'clientDataJSON': b64url(utf8.encode(clientData)),
        'authenticatorData': b64url(authData),
        'signature': b64url(sign(cred, authData, hash)),
        'userHandle': b64url(cred.userHandle),
      },
      'clientExtensionResults': <String, Object?>{},
    });
  }

  // -------------------------------------------------------------- helpers --

  static Uint8List _bigIntToBytes(BigInt v, int length) {
    final out = Uint8List(length);
    var x = v;
    for (var i = length - 1; i >= 0; i--) {
      out[i] = (x & BigInt.from(0xff)).toInt();
      x >>= 8;
    }
    return out;
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var r = BigInt.zero;
    for (final b in bytes) {
      r = (r << 8) | BigInt.from(b);
    }
    return r;
  }

  static List<int> _derInt(BigInt v) {
    var bytes = _bigIntToBytes(v, 33).toList();
    while (bytes.length > 1 && bytes[0] == 0 && bytes[1] < 0x80) {
      bytes = bytes.sublist(1);
    }
    return [0x02, bytes.length, ...bytes];
  }

  static Uint8List _derSignature(BigInt r, BigInt s) {
    final body = [..._derInt(r), ..._derInt(s)];
    return Uint8List.fromList([0x30, body.length, ...body]);
  }

  static (BigInt, BigInt) _parseDer(Uint8List der) {
    if (der[0] != 0x30) throw const FormatException('Bad DER signature');
    var i = 2;
    BigInt readInt() {
      if (der[i] != 0x02) throw const FormatException('Bad DER integer');
      final len = der[i + 1];
      final v = _bytesToBigInt(der.sublist(i + 2, i + 2 + len));
      i += 2 + len;
      return v;
    }

    return (readInt(), readInt());
  }
}
