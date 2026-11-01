import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/core/crypto/encoding.dart';
import 'package:vaultly/core/otp/totp.dart';

void main() {
  // RFC 6238 Appendix B test vectors (8 digits).
  final seeds = {
    OtpAlgorithm.sha1: '12345678901234567890',
    OtpAlgorithm.sha256: '12345678901234567890123456789012',
    OtpAlgorithm.sha512:
        '1234567890123456789012345678901234567890123456789012345678901234',
  };
  final vectors = <int, Map<OtpAlgorithm, String>>{
    59: {
      OtpAlgorithm.sha1: '94287082',
      OtpAlgorithm.sha256: '46119246',
      OtpAlgorithm.sha512: '90693936',
    },
    1111111109: {
      OtpAlgorithm.sha1: '07081804',
      OtpAlgorithm.sha256: '68084774',
      OtpAlgorithm.sha512: '25091201',
    },
    20000000000: {
      OtpAlgorithm.sha1: '65353130',
      OtpAlgorithm.sha256: '77737706',
      OtpAlgorithm.sha512: '47863826',
    },
  };

  vectors.forEach((time, expected) {
    expected.forEach((alg, code) {
      test('RFC 6238 $alg @ $time', () {
        final c = TotpConfig(
          secret: hexDecode(seeds[alg]!.codeUnits
              .map((u) => u.toRadixString(16).padLeft(2, '0'))
              .join()),
          digits: 8,
          algorithm: alg,
        );
        expect(
            c.codeAt(DateTime.fromMillisecondsSinceEpoch(time * 1000,
                isUtc: true)),
            code);
      });
    });
  });

  test('parses otpauth URIs', () {
    final c = TotpConfig.tryParse(
        'otpauth://totp/ACME%20Co:john@example.com?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=ACME%20Co&digits=8&period=60&algorithm=SHA256')!;
    expect(c.issuer, 'ACME Co');
    expect(c.account, 'john@example.com');
    expect(c.digits, 8);
    expect(c.period, 60);
    expect(c.algorithm, OtpAlgorithm.sha256);
  });

  test('parses bare base32 secrets and rejects junk', () {
    expect(TotpConfig.tryParse('JBSW Y3DP EHPK 3PXP'), isNotNull);
    expect(TotpConfig.tryParse('not a secret!'), isNull);
    expect(TotpConfig.tryParse('otpauth://hotp/x?secret=JBSWY3DPEHPK3PXP'),
        isNull);
  });
}
