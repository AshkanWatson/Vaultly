import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultly/app.dart';
import 'package:vaultly/data/app_settings.dart';
import 'package:vaultly/data/vault_service.dart';
import 'package:vaultly/data/vault_storage.dart';
import 'package:vaultly/state/providers.dart';

/// In-memory storage so widget tests don't need real file IO.
class MemoryVaultStorage extends VaultStorage {
  MemoryVaultStorage() : super(Directory('/nonexistent'));
  String? vault;
  String? settings;

  @override
  Future<bool> hasVault() async => vault != null;
  @override
  Future<String?> readVault() async => vault;
  @override
  Future<void> writeVault(String contents) async => vault = contents;
  @override
  Future<String?> readSettings() async => settings;
  @override
  Future<void> writeSettings(String contents) async => settings = contents;
  @override
  Future<void> erase() async => vault = null;
}

Widget testApp(VaultService service,
        {bool exists = false, AppSettings settings = const AppSettings()}) =>
    ProviderScope(
      overrides: [
        vaultServiceProvider.overrideWithValue(service),
        vaultExistsAtStartProvider.overrideWithValue(exists),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      child: const VaultlyApp(),
    );

/// Pumps frames without waiting for infinite animations (spinners) to end.
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets real async work (Argon2 isolates) finish.
Future<void> waitReal(WidgetTester tester, [int ms = 2500]) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
