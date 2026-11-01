import 'dart:math' as math;

import '../crypto/secure_random.dart';
import 'eff_wordlist.dart';

enum GeneratorMode { random, memorable, pin, apple }

extension GeneratorModeLabel on GeneratorMode {
  String get label => switch (this) {
        GeneratorMode.random => 'Random',
        GeneratorMode.memorable => 'Memorable',
        GeneratorMode.pin => 'PIN',
        GeneratorMode.apple => 'Easy to Type',
      };
}

class GeneratorOptions {
  const GeneratorOptions({
    this.mode = GeneratorMode.random,
    this.length = 20,
    this.uppercase = true,
    this.lowercase = true,
    this.digits = true,
    this.symbols = true,
    this.avoidAmbiguous = false,
    this.wordCount = 5,
    this.separator = '-',
    this.capitalize = true,
    this.includeNumber = true,
    this.pinLength = 6,
  });

  final GeneratorMode mode;
  final int length;
  final bool uppercase;
  final bool lowercase;
  final bool digits;
  final bool symbols;
  final bool avoidAmbiguous;
  final int wordCount;
  final String separator;
  final bool capitalize;
  final bool includeNumber;
  final int pinLength;

  static const int minLength = 4;
  static const int maxLength = 64;
  static const int minWords = 3;
  static const int maxWords = 12;
  static const int minPin = 4;
  static const int maxPin = 12;

  GeneratorOptions copyWith({
    GeneratorMode? mode,
    int? length,
    bool? uppercase,
    bool? lowercase,
    bool? digits,
    bool? symbols,
    bool? avoidAmbiguous,
    int? wordCount,
    String? separator,
    bool? capitalize,
    bool? includeNumber,
    int? pinLength,
  }) {
    final next = GeneratorOptions(
      mode: mode ?? this.mode,
      length: length ?? this.length,
      uppercase: uppercase ?? this.uppercase,
      lowercase: lowercase ?? this.lowercase,
      digits: digits ?? this.digits,
      symbols: symbols ?? this.symbols,
      avoidAmbiguous: avoidAmbiguous ?? this.avoidAmbiguous,
      wordCount: wordCount ?? this.wordCount,
      separator: separator ?? this.separator,
      capitalize: capitalize ?? this.capitalize,
      includeNumber: includeNumber ?? this.includeNumber,
      pinLength: pinLength ?? this.pinLength,
    );
    // Never allow every character class to be switched off.
    if (!next.uppercase && !next.lowercase && !next.digits && !next.symbols) {
      return this;
    }
    return next;
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'length': length,
        'upper': uppercase,
        'lower': lowercase,
        'digits': digits,
        'symbols': symbols,
        'ambiguous': avoidAmbiguous,
        'words': wordCount,
        'sep': separator,
        'cap': capitalize,
        'num': includeNumber,
        'pin': pinLength,
      };

  factory GeneratorOptions.fromJson(Map<String, dynamic> j) =>
      GeneratorOptions(
        mode: GeneratorMode.values.firstWhere((m) => m.name == j['mode'],
            orElse: () => GeneratorMode.random),
        length: (j['length'] as int? ?? 20).clamp(minLength, maxLength),
        uppercase: j['upper'] as bool? ?? true,
        lowercase: j['lower'] as bool? ?? true,
        digits: j['digits'] as bool? ?? true,
        symbols: j['symbols'] as bool? ?? true,
        avoidAmbiguous: j['ambiguous'] as bool? ?? false,
        wordCount: (j['words'] as int? ?? 5).clamp(minWords, maxWords),
        separator: j['sep'] as String? ?? '-',
        capitalize: j['cap'] as bool? ?? true,
        includeNumber: j['num'] as bool? ?? true,
        pinLength: (j['pin'] as int? ?? 6).clamp(minPin, maxPin),
      );
}

/// Generates passwords using only the OS CSPRNG.
class PasswordGenerator {
  PasswordGenerator._();

  static const String upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String lower = 'abcdefghijklmnopqrstuvwxyz';
  static const String digitChars = '0123456789';
  static const String symbolChars = r'!@#$%^&*()-_=+[]{};:,.?/~';
  static const String ambiguous = 'Il1|O0o';

  static String generate(GeneratorOptions o) => switch (o.mode) {
        GeneratorMode.random => _random(o),
        GeneratorMode.memorable => _memorable(o),
        GeneratorMode.pin => _pin(o.pinLength),
        GeneratorMode.apple => appleStyle(),
      };

  static String _strip(String pool, bool avoid) => avoid
      ? pool.split('').where((c) => !ambiguous.contains(c)).join()
      : pool;

  static List<String> _pools(GeneratorOptions o) => [
        if (o.uppercase) _strip(upper, o.avoidAmbiguous),
        if (o.lowercase) _strip(lower, o.avoidAmbiguous),
        if (o.digits) _strip(digitChars, o.avoidAmbiguous),
        if (o.symbols) _strip(symbolChars, o.avoidAmbiguous),
      ];

  static String _random(GeneratorOptions o) {
    final pools = _pools(o);
    final all = pools.join();
    final length = o.length.clamp(
        math.max(GeneratorOptions.minLength, pools.length),
        GeneratorOptions.maxLength);
    // One character from every selected class, the rest from the union,
    // then shuffle so the guaranteed characters are not at fixed positions.
    final chars = <String>[
      for (final p in pools) p[SecureRandomSource.nextInt(p.length)],
    ];
    while (chars.length < length) {
      chars.add(all[SecureRandomSource.nextInt(all.length)]);
    }
    SecureRandomSource.shuffle(chars);
    return chars.join();
  }

  static String _memorable(GeneratorOptions o) {
    final words = List.generate(o.wordCount, (_) {
      final w = effLargeWordlist[
          SecureRandomSource.nextInt(effLargeWordlist.length)];
      return o.capitalize ? w[0].toUpperCase() + w.substring(1) : w;
    });
    if (o.includeNumber) {
      final i = SecureRandomSource.nextInt(words.length);
      words[i] = '${words[i]}${SecureRandomSource.nextInt(10)}';
    }
    return words.join(o.separator);
  }

  static String _pin(int length) => List.generate(
          length, (_) => digitChars[SecureRandomSource.nextInt(10)])
      .join();

  /// Apple-style "strong password": three groups of six lowercase letters and
  /// digits separated by hyphens, with exactly one uppercase letter and one
  /// digit (e.g. `kibvoq-7ruxzy-Wefnyp`). Easy to type on phone keyboards.
  static String appleStyle() {
    const consonants = 'bcdfghjkmnpqrstvwxz';
    const vowels = 'aeiouy';
    final chars = <String>[];
    for (var i = 0; i < 18; i++) {
      final pool = i.isEven ? consonants : vowels;
      chars.add(pool[SecureRandomSource.nextInt(pool.length)]);
    }
    final digitPos = SecureRandomSource.nextInt(18);
    var upperPos = SecureRandomSource.nextInt(17);
    if (upperPos >= digitPos) upperPos++;
    chars[digitPos] = digitChars[SecureRandomSource.nextInt(10)];
    chars[upperPos] = chars[upperPos].toUpperCase();
    final s = chars.join();
    return '${s.substring(0, 6)}-${s.substring(6, 12)}-${s.substring(12)}';
  }

  /// Entropy (bits) of the generator configuration, i.e. how hard the output
  /// is to guess for an attacker who knows the settings.
  static double entropyBits(GeneratorOptions o) {
    double log2(num x) => math.log(x) / math.ln2;
    switch (o.mode) {
      case GeneratorMode.random:
        final n = _pools(o).join().length;
        return o.length * log2(n);
      case GeneratorMode.memorable:
        var bits = o.wordCount * log2(effLargeWordlist.length);
        if (o.includeNumber) bits += log2(10) + log2(o.wordCount);
        return bits;
      case GeneratorMode.pin:
        return o.pinLength * log2(10);
      case GeneratorMode.apple:
        // 9 consonants × 19 + 9 vowels × 6, plus digit & capital placement.
        return 9 * log2(19) + 9 * log2(6) + log2(18 * 17 * 10);
    }
  }
}
