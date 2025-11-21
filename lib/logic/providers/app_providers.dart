import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/credential_model.dart';
import '../../data/services/vault_repository.dart';

// 1. Repository Provider (Singleton access to logic)
final repositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository();
});

// 2. Credentials Provider (Async list state)
final credentialsProvider =
    FutureProvider.autoDispose<List<Credential>>((ref) async {
  // Whenever the repo changes, this could be invalidated to refresh UI
  final repo = ref.watch(repositoryProvider);
  return repo.getAllCredentials();
});

// 3. Theme Provider (Global App Theme State)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// 4. Auto-Lock Timer Provider
final autoLockTimerProvider = StateProvider<Timer?>((ref) => null);
