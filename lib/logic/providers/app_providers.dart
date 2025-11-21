import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/credential_model.dart';
import '../../data/services/vault_repository.dart';

final repositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository();
});


final credentialsProvider =
    FutureProvider.autoDispose<List<Credential>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getAllCredentials();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final autoLockTimerProvider = StateProvider<Timer?>((ref) => null);
