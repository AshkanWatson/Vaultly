import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils/constants.dart';
import 'logic/providers/app_providers.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/modules/auth/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Supabase using constants
  if (kSupabaseUrl != 'YOUR_SUPABASE_URL' && kSupabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: kSupabaseUrl,
      anonKey: kSupabaseAnonKey,
    );
  } else {
    print("Vaultly is running in OFFLINE MODE.");
  }

  runApp(const ProviderScope(child: VaultlyApp()));
}

class VaultlyApp extends ConsumerWidget {
  const VaultlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Listener(
      onPointerDown: (_) => _resetAutoLockTimer(ref),
      onPointerMove: (_) => _resetAutoLockTimer(ref),
      onPointerUp: (_) => _resetAutoLockTimer(ref),
      child: MaterialApp(
        title: 'Vaultly',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        navigatorKey: GlobalKey<NavigatorState>(),
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        home: const LockScreen(),
      ),
    );
  }

  void _resetAutoLockTimer(WidgetRef ref) {
    ref.read(autoLockTimerProvider)?.cancel();
    final repo = ref.read(repositoryProvider);

    if (repo.isUnlocked) {
      ref.read(autoLockTimerProvider.notifier).state =
          Timer(const Duration(minutes: 2), () {
        repo.lock();
        runApp(const ProviderScope(child: VaultlyApp()));
      });
    }
  }
}
