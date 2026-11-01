import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/core/generator/eff_wordlist.dart';
import 'package:vaultly/core/generator/password_generator.dart';
import 'package:vaultly/core/security/password_strength.dart';

void main() {
  group('PasswordGenerator', () {
    test('random passwords honour length and include every class', () {
      for (var i = 0; i < 200; i++) {
        final p = PasswordGenerator.generate(const GeneratorOptions(length: 12));
        expect(p.length, 12);
        expect(p, matches(RegExp(r'[A-Z]')));
        expect(p, matches(RegExp(r'[a-z]')));
        expect(p, matches(RegExp(r'[0-9]')));
        expect(p, matches(RegExp(r'[^A-Za-z0-9]')));
      }
    });

    test('respects disabled classes and ambiguous-character filter', () {
      const o = GeneratorOptions(
          length: 64, symbols: false, uppercase: false, avoidAmbiguous: true);
      for (var i = 0; i < 50; i++) {
        final p = PasswordGenerator.generate(o);
        expect(p, matches(RegExp(r'^[a-z0-9]+$')));
        expect(p, isNot(matches(RegExp(r'[l1o0]'))));
      }
    });

    test('cannot disable every character class', () {
      const o = GeneratorOptions(symbols: false, digits: false, uppercase: false);
      expect(o.copyWith(lowercase: false).lowercase, isTrue);
    });

    test('memorable passphrases use the EFF list', () {
      expect(effLargeWordlist, hasLength(7776));
      final p = PasswordGenerator.generate(const GeneratorOptions(
          mode: GeneratorMode.memorable,
          wordCount: 6,
          separator: '.',
          capitalize: false,
          includeNumber: false));
      final words = p.split('.');
      expect(words, hasLength(6));
      for (final w in words) {
        expect(effLargeWordlist, contains(w));
      }
    });

    test('PIN and Apple-style formats', () {
      expect(
          PasswordGenerator.generate(
              const GeneratorOptions(mode: GeneratorMode.pin, pinLength: 8)),
          matches(RegExp(r'^\d{8}$')));
      for (var i = 0; i < 100; i++) {
        final p = PasswordGenerator.appleStyle();
        expect(p, matches(RegExp(r'^[a-zA-Z0-9]{6}-[a-zA-Z0-9]{6}-[a-zA-Z0-9]{6}$')));
        expect(RegExp(r'[A-Z]').allMatches(p), hasLength(1));
        expect(RegExp(r'[0-9]').allMatches(p), hasLength(1));
      }
    });

    test('generated passwords are unique', () {
      final set = {
        for (var i = 0; i < 1000; i++)
          PasswordGenerator.generate(const GeneratorOptions())
      };
      expect(set, hasLength(1000));
    });

    test('entropy estimate', () {
      expect(PasswordGenerator.entropyBits(const GeneratorOptions(length: 20)),
          closeTo(20 * 6.44, 0.1));
      expect(
          PasswordGenerator.entropyBits(const GeneratorOptions(
              mode: GeneratorMode.memorable, wordCount: 5, includeNumber: false)),
          closeTo(64.6, 0.1));
    });
  });

  group('PasswordStrength', () {
    test('flags common and patterned passwords', () {
      for (final p in ['password', 'P@ssw0rd', '123456', 'qwerty123', 'aaaaaaa']) {
        expect(PasswordStrength.evaluate(p).level.isWeak, isTrue, reason: p);
      }
    });

    test('rates generated passwords as strong', () {
      final p = PasswordGenerator.generate(const GeneratorOptions(length: 20));
      expect(PasswordStrength.evaluate(p).level.index,
          greaterThanOrEqualTo(StrengthLevel.strong.index));
      expect(PasswordStrength.evaluate('kibvoq-7ruxzy-Wefnyp').level.index,
          greaterThanOrEqualTo(StrengthLevel.strong.index));
    });
  });
}
