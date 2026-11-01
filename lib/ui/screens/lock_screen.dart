import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/biometric_service.dart';
import '../../data/native_bridge.dart';
import '../../data/vault_envelope.dart';
import '../../state/providers.dart';
import '../actions.dart';
import '../theme/app_theme.dart';
import '../widgets/grouped.dart';
import 'setup_screen.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _pw = TextEditingController();
  final _focus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  int _shake = 0;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoBiometric());
  }

  @override
  void dispose() {
    _pw.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _autoBiometric() async {
    if (!ref.read(settingsProvider).biometricEnabled) {
      _focus.requestFocus();
      return;
    }
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    await _biometric();
  }

  Future<void> _biometric() async {
    final ok = await AutoLockGuard.run(
        () => ref.read(vaultProvider.notifier).unlockWithBiometrics());
    if (!ok && mounted) _focus.requestFocus();
  }

  Future<void> _unlock() async {
    if (_pw.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(vaultProvider.notifier).unlock(_pw.text);
    } on WrongPasswordException {
      _failures++;
      if (!mounted) return;
      setState(() {
        _error = _failures >= 3
            ? 'Incorrect password. Check Caps Lock and your keyboard layout.'
            : 'Incorrect password';
        _shake++;
        _pw.clear();
      });
      _focus.requestFocus();
    } on VaultFormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final kind = ref.watch(biometricKindProvider).value ?? BiometricKind.none;
    final passkey = ref.watch(passkeyRequestProvider);
    final showBio = settings.biometricEnabled && kind != BiometricKind.none;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const AppBadge(size: 80),
                  const SizedBox(height: 24),
                  Text('Vaultly is Locked', style: context.text.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    passkey != null
                        ? 'Unlock to use your passkey${passkey.origin.isEmpty ? '' : ' for ${Uri.tryParse(passkey.origin)?.host ?? passkey.origin}'}.'
                        : 'Enter your master password to unlock.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: c.secondaryLabel),
                  ),
                  const SizedBox(height: 28),
                  TweenAnimationBuilder<double>(
                    key: ValueKey(_shake),
                    tween: Tween(begin: _shake == 0 ? 1 : 0, end: 1),
                    duration: const Duration(milliseconds: 420),
                    builder: (context, t, child) => Transform.translate(
                      offset: Offset(math.sin(t * math.pi * 6) * 10 * (1 - t), 0),
                      child: child,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _error != null ? c.red : Colors.transparent),
                      ),
                      child: InputRow(
                        controller: _pw,
                        focusNode: _focus,
                        placeholder: 'Master Password',
                        obscure: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _unlock(),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        trailing: IconButton(
                          icon: Icon(
                              _obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                              size: 20,
                              color: c.gray),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: _error == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: c.red, fontSize: 13)),
                          ),
                  ),
                  PillButton(label: 'Unlock', loading: _busy, onPressed: _unlock),
                  if (showBio) ...[
                    const SizedBox(height: 12),
                    PillButton(
                      label: 'Unlock with ${kind.label}',
                      icon: kind == BiometricKind.faceId
                          ? Icons.face_unlock_outlined
                          : Icons.fingerprint,
                      tinted: true,
                      onPressed: _busy ? null : _biometric,
                    ),
                  ],
                  if (passkey != null) ...[
                    const SizedBox(height: 12),
                    CupertinoButton(
                      onPressed: () => NativeBridge.cancelPasskeyRequest(),
                      child: const Text('Cancel'),
                    ),
                  ],
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.airplane, size: 13, color: c.tertiaryLabel),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('Offline · AES-256-GCM · Argon2id',
                            style: TextStyle(fontSize: 12, color: c.tertiaryLabel)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
