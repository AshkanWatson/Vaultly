import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:vaultly/core/crypto/encoding.dart';
import 'package:vaultly/core/passkey/cbor.dart';
import 'package:vaultly/core/passkey/webauthn.dart';

const _createJson = '''
{
  "rp": {"id": "example.com", "name": "Example"},
  "user": {"id": "dXNlci1oYW5kbGU", "name": "alice@example.com", "displayName": "Alice"},
  "challenge": "dGVzdC1jaGFsbGVuZ2U",
  "pubKeyCredParams": [{"type": "public-key", "alg": -8}, {"type": "public-key", "alg": -7}],
  "authenticatorSelection": {"residentKey": "required", "userVerification": "required"}
}''';

Uint8List _sha256(List<int> b) =>
    SHA256Digest().process(Uint8List.fromList(b));

void main() {
  test('CBOR canonical encoding and round-trip', () {
    expect(hex(Cbor.encode(0)), '00');
    expect(hex(Cbor.encode(-7)), '26');
    expect(hex(Cbor.encode(1000000)), '1a000f4240');
    expect(hex(Cbor.encode('a')), '6161');
    // CTAP2 canonical: shorter keys first ("fmt" < "attStmt" < "authData").
    final enc = Cbor.encode({'authData': Uint8List(1), 'fmt': 'none', 'attStmt': {}});
    expect(hex(enc).startsWith('a363666d74'), isTrue);
    final m = Cbor.decode(enc) as Map;
    expect(m['fmt'], 'none');
  });

  test('registration produces a valid attestation object', () {
    final (cred, json) = WebAuthnAuthenticator.register(
        CreationRequest.fromJson(_createJson),
        origin: 'https://example.com');
    final r = jsonDecode(json) as Map<String, dynamic>;
    final resp = r['response'] as Map<String, dynamic>;
    expect(r['id'], cred.credentialIdB64);
    expect(resp['publicKeyAlgorithm'], -7);

    final client = jsonDecode(utf8.decode(b64urlDecode(resp['clientDataJSON'])));
    expect(client['type'], 'webauthn.create');
    expect(client['challenge'], 'dGVzdC1jaGFsbGVuZ2U');
    expect(client['origin'], 'https://example.com');

    final att = Cbor.decode(b64urlDecode(resp['attestationObject'])) as Map;
    expect(att['fmt'], 'none');
    final authData = att['authData'] as Uint8List;
    expect(authData.sublist(0, 32), _sha256(utf8.encode('example.com')));
    final flags = authData[32];
    expect(flags & 0x01, 0x01, reason: 'UP');
    expect(flags & 0x04, 0x04, reason: 'UV');
    expect(flags & 0x40, 0x40, reason: 'AT');
    final credLen = (authData[53] << 8) | authData[54];
    expect(authData.sublist(55, 55 + credLen), cred.credentialId);
    final cose = Cbor.decode(authData.sublist(55 + credLen)) as Map;
    expect(cose[1], 2);
    expect(cose[3], -7);
    final (x, y) = WebAuthnAuthenticator.publicCoordinates(cred);
    expect(cose[-2], x);
    expect(cose[-3], y);
    expect(cred.userHandle, utf8.encode('user-handle'));
  });

  test('assertions verify against the registered public key', () {
    final (cred, _) = WebAuthnAuthenticator.register(
        CreationRequest.fromJson(_createJson),
        origin: 'https://example.com');
    final req = AssertionRequest.fromJson(
        '{"rpId":"example.com","challenge":"YXV0aC1jaGFsbGVuZ2U","allowCredentials":[]}');
    final json = WebAuthnAuthenticator.assertion(cred, req,
        origin: 'https://example.com');
    final resp = (jsonDecode(json) as Map)['response'] as Map;
    final authData = b64urlDecode(resp['authenticatorData']);
    final clientData = b64urlDecode(resp['clientDataJSON']);
    final sig = b64urlDecode(resp['signature']);
    expect(authData[32] & 0x40, 0, reason: 'no attested data on assertion');
    final ok = WebAuthnAuthenticator.verify(
      WebAuthnAuthenticator.publicKeyOf(cred),
      Uint8List.fromList([...authData, ..._sha256(clientData)]),
      sig,
    );
    expect(ok, isTrue);
    expect(b64urlDecode(resp['userHandle']), cred.userHandle);
  });

  test('assertions sign a browser-provided clientDataHash', () {
    final (cred, _) = WebAuthnAuthenticator.register(
        CreationRequest.fromJson(_createJson),
        origin: 'https://example.com');
    final hash = _sha256(utf8.encode('browser-built client data'));
    final json = WebAuthnAuthenticator.assertion(
        cred,
        AssertionRequest.fromJson('{"rpId":"example.com","challenge":"AA"}'),
        origin: 'https://example.com',
        clientDataHash: hash);
    final resp = (jsonDecode(json) as Map)['response'] as Map;
    expect(
        WebAuthnAuthenticator.verify(
          WebAuthnAuthenticator.publicKeyOf(cred),
          Uint8List.fromList([...b64urlDecode(resp['authenticatorData']), ...hash]),
          b64urlDecode(resp['signature']),
        ),
        isTrue);
  });

  test('rejects unsupported algorithms, excluded and foreign credentials', () {
    expect(
        () => WebAuthnAuthenticator.register(
            CreationRequest.fromJson(_createJson.replaceAll('-7}', '-257}')),
            origin: 'https://example.com'),
        throwsA(isA<WebAuthnException>()));

    final (cred, _) = WebAuthnAuthenticator.register(
        CreationRequest.fromJson(_createJson),
        origin: 'https://example.com');
    final excluding = _createJson.replaceFirst('"authenticatorSelection"',
        '"excludeCredentials":[{"type":"public-key","id":"${cred.credentialIdB64}"}],"authenticatorSelection"');
    expect(
        () => WebAuthnAuthenticator.register(CreationRequest.fromJson(excluding),
            origin: 'https://example.com', existing: [cred]),
        throwsA(isA<WebAuthnException>()));
    expect(
        () => WebAuthnAuthenticator.assertion(
            cred,
            AssertionRequest.fromJson('{"rpId":"evil.com","challenge":"AA"}'),
            origin: 'https://evil.com'),
        throwsA(isA<WebAuthnException>()));
  });

  test('SPKI public key has the P-256 header', () {
    final (cred, _) = WebAuthnAuthenticator.register(
        CreationRequest.fromJson(_createJson),
        origin: 'https://example.com');
    final spki = WebAuthnAuthenticator.spki(cred);
    expect(spki, hasLength(91));
    expect(hex(spki.sublist(0, 4)), '30593013');
  });
}
