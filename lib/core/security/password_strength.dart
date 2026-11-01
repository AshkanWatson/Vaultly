import 'dart:math' as math;

enum StrengthLevel { veryWeak, weak, fair, strong, veryStrong }

extension StrengthLevelLabel on StrengthLevel {
  String get label => switch (this) {
        StrengthLevel.veryWeak => 'Very Weak',
        StrengthLevel.weak => 'Weak',
        StrengthLevel.fair => 'Fair',
        StrengthLevel.strong => 'Strong',
        StrengthLevel.veryStrong => 'Very Strong',
      };

  /// 0.0 – 1.0, for meters.
  double get fraction => (index + 1) / StrengthLevel.values.length;

  bool get isWeak => index <= StrengthLevel.weak.index;
}

class StrengthResult {
  const StrengthResult(this.level, this.bits, this.warning);
  final StrengthLevel level;

  /// Estimated guessing entropy after pattern penalties.
  final double bits;
  final String? warning;
}

/// Offline password strength estimator.
///
/// Character-pool entropy with penalties for the patterns attackers try
/// first: common passwords, keyboard walks, sequences, repeats, dates and
/// leetspeak dictionary words. It is deliberately conservative.
class PasswordStrength {
  PasswordStrength._();

  static const _common = {
    '123456', '123456789', '12345678', 'password', 'qwerty', '12345',
    '1234567', '111111', '123123', 'abc123', '1234567890', '1234',
    'password1', 'iloveyou', '000000', 'qwerty123', 'admin', 'welcome',
    'monkey', 'dragon', 'letmein', 'football', 'baseball', 'master',
    'sunshine', 'princess', 'shadow', 'superman', 'michael', 'charlie',
    'passw0rd', 'trustno1', 'starwars', 'whatever', 'hello', 'freedom',
    'qazwsx', 'zaq12wsx', 'asdfgh', 'asdf', 'login', 'access', 'secret',
    'test', 'guest', 'root', 'changeme', 'default', 'computer', 'internet',
    'ninja', 'mustang', 'jordan', 'hunter', 'killer', 'soccer', 'hockey',
    'batman', 'andrew', 'pepper', 'summer', 'winter', 'spring', 'autumn',
    'love', 'lovely', 'flower', 'cookie', 'cheese', 'banana', 'orange',
    'samsung', 'google', 'apple', 'facebook', 'instagram', 'linkedin',
    'p@ssw0rd', 'p@ssword', 'pa55word', 'qwertyuiop', '1q2w3e4r',
    '1qaz2wsx', '987654321', '654321', '121212', '666666', '696969',
    '7777777', '888888', 'aaaaaa', 'abcdef', 'abcd1234', 'mypassword',
    'vaultly',
  };

  static const _rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm', '1234567890'];

  static StrengthResult evaluate(String password) {
    if (password.isEmpty) {
      return const StrengthResult(StrengthLevel.veryWeak, 0, null);
    }
    final lower = password.toLowerCase();
    final deLeet = lower
        .replaceAll('@', 'a')
        .replaceAll('4', 'a')
        .replaceAll('3', 'e')
        .replaceAll('1', 'i')
        .replaceAll('!', 'i')
        .replaceAll('0', 'o')
        .replaceAll(r'$', 's')
        .replaceAll('5', 's')
        .replaceAll('7', 't');
    final stripped = deLeet.replaceAll(RegExp(r'[^a-z]'), '');

    if (_common.contains(lower) ||
        _common.contains(deLeet) ||
        (stripped.length >= 4 && _common.contains(stripped) &&
            password.length - stripped.length <= 4)) {
      return const StrengthResult(
          StrengthLevel.veryWeak, 0, 'This is a commonly used password.');
    }

    var pool = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) pool += 26;
    if (RegExp(r'[A-Z]').hasMatch(password)) pool += 26;
    if (RegExp(r'[0-9]').hasMatch(password)) pool += 10;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) pool += 33;

    // Count "effective" characters: repeats and sequential runs are nearly
    // free for an attacker, so they only count as a fraction.
    var effective = 0.0;
    String? warning;
    for (var i = 0; i < password.length; i++) {
      if (i > 0 && password[i] == password[i - 1]) {
        effective += 0.2;
        warning ??= 'Avoid repeated characters.';
      } else if (i > 0 && _isSequential(lower, i)) {
        effective += 0.3;
        warning ??= 'Avoid sequences like "abc" or "123".';
      } else {
        effective += 1;
      }
    }

    var bits = effective * (math.log(pool) / math.ln2);

    for (final row in _rows) {
      for (var len = row.length; len >= 4; len--) {
        for (var s = 0; s + len <= row.length; s++) {
          if (lower.contains(row.substring(s, s + len))) {
            bits -= len * 2.5;
            warning ??= 'Avoid keyboard patterns.';
            len = 0;
            break;
          }
        }
      }
    }
    if (RegExp(r'(19|20)\d{2}').hasMatch(password)) {
      bits -= 8;
      warning ??= 'Avoid years and dates.';
    }
    if (password.length < 8) warning ??= 'Use at least 12 characters.';

    bits = math.max(0, bits);
    final level = bits < 28
        ? StrengthLevel.veryWeak
        : bits < 40
            ? StrengthLevel.weak
            : bits < 60
                ? StrengthLevel.fair
                : bits < 80
                    ? StrengthLevel.strong
                    : StrengthLevel.veryStrong;
    return StrengthResult(level, bits, level.isWeak ? warning : null);
  }

  static bool _isSequential(String s, int i) {
    final a = s.codeUnitAt(i - 1);
    final b = s.codeUnitAt(i);
    return (b - a).abs() == 1 &&
        (RegExp(r'[a-z0-9]').hasMatch(s[i - 1]) &&
            RegExp(r'[a-z0-9]').hasMatch(s[i]));
  }

  /// Describes generator entropy using the same scale.
  static StrengthLevel levelForBits(double bits) => bits < 28
      ? StrengthLevel.veryWeak
      : bits < 40
          ? StrengthLevel.weak
          : bits < 60
              ? StrengthLevel.fair
              : bits < 80
                  ? StrengthLevel.strong
                  : StrengthLevel.veryStrong;
}
