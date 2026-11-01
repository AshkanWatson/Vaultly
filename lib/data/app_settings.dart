import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/generator/password_generator.dart';

/// Non-secret preferences, stored in plaintext next to the vault so they can
/// be applied before unlock (theme, lock timing). Never put secrets here.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.autoLockSeconds = 120,
    this.clipboardSeconds = 60,
    this.biometricEnabled = false,
    this.generator = const GeneratorOptions(),
  });

  final ThemeMode themeMode;

  /// 0 = lock immediately when the app goes to the background,
  /// -1 = never auto-lock (still locks on restart).
  final int autoLockSeconds;

  /// 0 = never clear the clipboard.
  final int clipboardSeconds;
  final bool biometricEnabled;
  final GeneratorOptions generator;

  static const autoLockChoices = <int, String>{
    0: 'Immediately',
    60: 'After 1 minute',
    120: 'After 2 minutes',
    300: 'After 5 minutes',
    900: 'After 15 minutes',
    3600: 'After 1 hour',
    -1: 'Never',
  };

  static const clipboardChoices = <int, String>{
    30: 'After 30 seconds',
    60: 'After 1 minute',
    120: 'After 2 minutes',
    0: 'Never',
  };

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? autoLockSeconds,
    int? clipboardSeconds,
    bool? biometricEnabled,
    GeneratorOptions? generator,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
        clipboardSeconds: clipboardSeconds ?? this.clipboardSeconds,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        generator: generator ?? this.generator,
      );

  String encode() => jsonEncode({
        'theme': themeMode.name,
        'autoLock': autoLockSeconds,
        'clipboard': clipboardSeconds,
        'biometric': biometricEnabled,
        'generator': generator.toJson(),
      });

  static AppSettings decode(String? text) {
    if (text == null) return const AppSettings();
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      return AppSettings(
        themeMode: ThemeMode.values.firstWhere((m) => m.name == j['theme'],
            orElse: () => ThemeMode.system),
        autoLockSeconds: j['autoLock'] as int? ?? 120,
        clipboardSeconds: j['clipboard'] as int? ?? 60,
        biometricEnabled: j['biometric'] as bool? ?? false,
        generator: j['generator'] is Map
            ? GeneratorOptions.fromJson(
                (j['generator'] as Map).cast<String, dynamic>())
            : const GeneratorOptions(),
      );
    } catch (_) {
      return const AppSettings();
    }
  }
}
