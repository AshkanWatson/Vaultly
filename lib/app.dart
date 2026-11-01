import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/actions.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/lock_screen.dart';
import 'ui/screens/passkey_request_screen.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/theme/app_theme.dart';

class VaultlyApp extends ConsumerWidget {
  const VaultlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'Vaultly',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) => AutoLock(child: PrivacyShield(child: child!)),
      home: const VaultGate(),
    );
  }
}

/// Chooses the root screen from the vault status.
class VaultGate extends ConsumerWidget {
  const VaultGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(vaultProvider.select((s) => s.status));
    final passkey = ref.watch(passkeyRequestProvider);
    final Widget screen = switch (status) {
      VaultStatus.setup => const SetupScreen(),
      VaultStatus.locked => const LockScreen(),
      VaultStatus.unlocked =>
        passkey != null ? PasskeyRequestScreen(request: passkey) : const HomeShell(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(status), child: screen),
    );
  }
}

/// Locks the vault after inactivity and/or when the app is backgrounded.
class AutoLock extends ConsumerStatefulWidget {
  const AutoLock({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AutoLock> createState() => _AutoLockState();
}

class _AutoLockState extends ConsumerState<AutoLock> {
  Timer? _timer;
  DateTime? _backgroundedAt;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  int get _seconds => ref.read(settingsProvider).autoLockSeconds;
  bool get _unlocked =>
      ref.read(vaultProvider).status == VaultStatus.unlocked;

  void _onLifecycle(AppLifecycleState s) {
    if (s == AppLifecycleState.hidden || s == AppLifecycleState.paused) {
      if (AutoLockGuard.active) return;
      _backgroundedAt ??= DateTime.now();
      if (_seconds == 0) _lock();
    } else if (s == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null &&
          _seconds >= 0 &&
          DateTime.now().difference(since).inSeconds >= _seconds) {
        _lock();
      } else {
        _reset();
      }
    }
  }

  void _reset() {
    _timer?.cancel();
    final s = _seconds;
    if (s > 0 && _unlocked) _timer = Timer(Duration(seconds: s), _lock);
  }

  void _lock() {
    _timer?.cancel();
    if (!_unlocked) return;
    rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    ref.read(vaultProvider.notifier).lock();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultProvider.select((s) => s.status), (_, _) => _reset());
    ref.listen(settingsProvider.select((s) => s.autoLockSeconds), (_, _) => _reset());
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reset(),
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, _) {
          _reset();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}

/// Covers the UI while the app is inactive so passwords never show up in the
/// iOS app switcher / Android recents (Android also uses FLAG_SECURE).
class PrivacyShield extends StatefulWidget {
  const PrivacyShield({super.key, required this.child});
  final Widget child;

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield> {
  bool _covered = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (s) {
      final cover = s != AppLifecycleState.resumed && !AutoLockGuard.active;
      if (cover != _covered) setState(() => _covered = cover);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        widget.child,
        if (_covered)
          Positioned.fill(
            child: ColoredBox(
              color: c.background,
              child: Center(
                child: Icon(Icons.lock_rounded, size: 56, color: c.gray),
              ),
            ),
          ),
      ],
    );
  }
}
