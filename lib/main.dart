import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/app_settings.dart';
import 'data/native_bridge.dart';
import 'data/vault_service.dart';
import 'data/vault_storage.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // App-private storage (sandboxed per platform). Nothing is ever uploaded.
  final support = await getApplicationSupportDirectory();
  final storage = VaultStorage(Directory(p.join(support.path, 'vault')));
  final settings = AppSettings.decode(await storage.readSettings());
  final exists = await storage.hasVault();
  final passkeyRequest = await NativeBridge.pendingPasskeyRequest();

  runApp(ProviderScope(
    overrides: [
      vaultServiceProvider.overrideWithValue(VaultService(storage)),
      initialSettingsProvider.overrideWithValue(settings),
      vaultExistsAtStartProvider.overrideWithValue(exists),
      passkeyRequestProvider.overrideWithValue(passkeyRequest),
    ],
    child: const VaultlyApp(),
  ));
}
