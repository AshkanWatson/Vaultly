import 'dart:convert';
import 'dart:typed_data';

/// Base64url without padding (used by WebAuthn).
String b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List b64urlDecode(String input) {
  var s = input.replaceAll('-', '+').replaceAll('_', '/').trim();
  while (s.length % 4 != 0) {
    s += '=';
  }
  return base64.decode(s);
}

String b64(List<int> bytes) => base64.encode(bytes);

Uint8List b64Decode(String input) => base64.decode(input);

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List hexDecode(String input) {
  final s = input.replaceAll(RegExp(r'\s'), '');
  if (s.length.isOdd) throw const FormatException('Odd-length hex string');
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

const _b32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// RFC 4648 base32 decoding (used by TOTP secrets). Case, spaces, dashes and
/// padding are ignored.
Uint8List base32Decode(String input) {
  final s = input.toUpperCase().replaceAll(RegExp(r'[\s=\-]'), '');
  final out = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final ch in s.split('')) {
    final v = _b32Alphabet.indexOf(ch);
    if (v < 0) throw FormatException('Invalid base32 character: $ch');
    buffer = (buffer << 5) | v;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.add((buffer >> bits) & 0xff);
    }
  }
  return Uint8List.fromList(out);
}

String base32Encode(List<int> bytes) {
  final sb = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      sb.write(_b32Alphabet[(buffer >> bits) & 31]);
    }
  }
  if (bits > 0) sb.write(_b32Alphabet[(buffer << (5 - bits)) & 31]);
  return sb.toString();
}

/// Constant-time comparison.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Best-effort wipe of sensitive bytes held in memory.
void wipe(Uint8List? bytes) {
  if (bytes == null) return;
  bytes.fillRange(0, bytes.length, 0);
}
