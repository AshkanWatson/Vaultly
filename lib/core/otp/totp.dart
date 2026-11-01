import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../crypto/encoding.dart';

enum OtpAlgorithm { sha1, sha256, sha512 }

/// TOTP (RFC 6238) configuration, parsed from an `otpauth://` URI or a bare
/// base32 secret.
class TotpConfig {
  const TotpConfig({
    required this.secret,
    this.digits = 6,
    this.period = 30,
    this.algorithm = OtpAlgorithm.sha1,
    this.issuer,
    this.account,
  });

  final Uint8List secret;
  final int digits;
  final int period;
  final OtpAlgorithm algorithm;
  final String? issuer;
  final String? account;

  /// Returns null when [input] is not a valid TOTP secret/URI.
  static TotpConfig? tryParse(String? input) {
    if (input == null) return null;
    final text = input.trim();
    if (text.isEmpty) return null;
    try {
      if (text.toLowerCase().startsWith('otpauth://')) {
        final uri = Uri.parse(text);
        if (uri.host.toLowerCase() != 'totp') return null;
        final q = uri.queryParameters;
        final secret = base32Decode(q['secret'] ?? '');
        if (secret.isEmpty) return null;
        final label = Uri.decodeComponent(
            uri.path.startsWith('/') ? uri.path.substring(1) : uri.path);
        String? issuer = q['issuer'];
        String? account = label;
        if (label.contains(':')) {
          final i = label.indexOf(':');
          issuer ??= label.substring(0, i);
          account = label.substring(i + 1).trim();
        }
        final digits = int.tryParse(q['digits'] ?? '') ?? 6;
        final period = int.tryParse(q['period'] ?? '') ?? 30;
        if (digits < 6 || digits > 10 || period < 1 || period > 300) {
          return null;
        }
        return TotpConfig(
          secret: secret,
          digits: digits,
          period: period,
          algorithm: switch ((q['algorithm'] ?? 'SHA1').toUpperCase()) {
            'SHA256' => OtpAlgorithm.sha256,
            'SHA512' => OtpAlgorithm.sha512,
            _ => OtpAlgorithm.sha1,
          },
          issuer: issuer,
          account: account,
        );
      }
      final secret = base32Decode(text);
      if (secret.length < 10) return null; // < 80 bits is not a real secret
      return TotpConfig(secret: secret);
    } on FormatException {
      return null;
    }
  }

  Digest _digest() => switch (algorithm) {
        OtpAlgorithm.sha1 => SHA1Digest(),
        OtpAlgorithm.sha256 => SHA256Digest(),
        OtpAlgorithm.sha512 => SHA512Digest(),
      };

  /// HOTP (RFC 4226) for a given counter.
  String hotp(int counter) {
    final mac = HMac(_digest(), algorithm == OtpAlgorithm.sha512 ? 128 : 64)
      ..init(KeyParameter(secret));
    final msg = Uint8List(8);
    var c = counter;
    for (var i = 7; i >= 0; i--) {
      msg[i] = c & 0xff;
      c >>= 8;
    }
    final h = mac.process(msg);
    final o = h[h.length - 1] & 0x0f;
    final bin = ((h[o] & 0x7f) << 24) |
        (h[o + 1] << 16) |
        (h[o + 2] << 8) |
        h[o + 3];
    var mod = 1;
    for (var i = 0; i < digits; i++) {
      mod *= 10;
    }
    return (bin % mod).toString().padLeft(digits, '0');
  }

  String codeAt(DateTime time) =>
      hotp(time.millisecondsSinceEpoch ~/ 1000 ~/ period);

  /// Seconds until the current code changes.
  int secondsRemaining(DateTime time) =>
      period - (time.millisecondsSinceEpoch ~/ 1000) % period;
}
