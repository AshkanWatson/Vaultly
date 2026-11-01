import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/generator/password_generator.dart';
import '../../core/security/password_strength.dart';
import '../../data/biometric_service.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/grouped.dart';
import '../widgets/password_widgets.dart';
import 'import_export.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({super.key, this.size = 88});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.23),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.teal, c.blue, c.indigo],
        ),
        boxShadow: [
          BoxShadow(
              color: c.blue.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Icon(Icons.key_rounded, color: Colors.white, size: size * 0.52),
    );
  }
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget feature(IconData icon, Color color, String title, String body) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: TextStyle(
                            fontSize: 15, color: c.secondaryLabel, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
                    children: [
                      const Center(child: AppBadge()),
                      const SizedBox(height: 24),
                      Text('Welcome to Vaultly',
                          textAlign: TextAlign.center,
                          style: context.text.displaySmall),
                      const SizedBox(height: 8),
                      Text(
                        'Your passwords, passkeys and codes — encrypted and kept only on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, color: c.secondaryLabel),
                      ),
                      const SizedBox(height: 28),
                      feature(CupertinoIcons.airplane, c.orange, 'Completely Offline',
                          'No account, no cloud, no tracking. Your vault never leaves this device.'),
                      feature(CupertinoIcons.lock_shield_fill, c.blue, 'Strong Encryption',
                          'AES-256-GCM with a key derived from your master password using Argon2id.'),
                      feature(CupertinoIcons.person_crop_circle_badge_checkmark, c.green,
                          'Passkeys, Codes & More',
                          'Store passkeys, two-factor codes, Wi-Fi networks and secure notes.'),
                      feature(CupertinoIcons.wand_stars, c.purple, 'Password Generator',
                          'Create strong random passwords, memorable passphrases and PINs.'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
                  child: Column(children: [
                    PillButton(
                      label: 'Create Vault',
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CreateMasterPasswordScreen())),
                    ),
                    const SizedBox(height: 12),
                    PillButton(
                      label: 'Restore from Backup',
                      tinted: true,
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              const CreateMasterPasswordScreen(restore: true))),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateMasterPasswordScreen extends ConsumerStatefulWidget {
  const CreateMasterPasswordScreen({super.key, this.restore = false});
  final bool restore;

  @override
  ConsumerState<CreateMasterPasswordScreen> createState() =>
      _CreateMasterPasswordScreenState();
}

class _CreateMasterPasswordScreenState
    extends ConsumerState<CreateMasterPasswordScreen> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  StrengthResult get _strength => PasswordStrength.evaluate(_pw.text);

  bool get _valid =>
      _pw.text.length >= 8 &&
      _pw.text == _confirm.text &&
      _strength.level.index >= StrengthLevel.fair.index;

  void _suggest() {
    final p = PasswordGenerator.generate(const GeneratorOptions(
        mode: GeneratorMode.memorable, wordCount: 5, separator: '-'));
    setState(() {
      _pw.text = p;
      _confirm.text = p;
      _obscure = false;
    });
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      await ref.read(vaultProvider.notifier).create(_pw.text);
      if (!mounted) return;
      final kind = await ref.read(biometricKindProvider.future);
      if (kind != BiometricKind.none && mounted) {
        final enable = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text('Use ${kind.label}?'),
            content: Text(
                'Unlock Vaultly with ${kind.label} instead of typing your master password.'),
            actions: [
              CupertinoDialogAction(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Not Now')),
              CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Turn On')),
            ],
          ),
        );
        if (enable == true) {
          await ref.read(vaultProvider.notifier).enableBiometrics();
        }
      }
      nav.popUntil((r) => r.isFirst);
      if (widget.restore) {
        final ctx = nav.context;
        if (ctx.mounted) await importBackupFlow(ctx, ref);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _strength;
    final mismatch = _confirm.text.isNotEmpty && _confirm.text != _pw.text;
    return Scaffold(
      appBar: CupertinoNavigationBar(
        previousPageTitle: 'Welcome',
        middle: const Text('Master Password'),
        backgroundColor: c.background,
        border: null,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.only(top: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
                  child: Column(
                    children: [
                      Icon(CupertinoIcons.lock_shield_fill, size: 56, color: c.blue),
                      const SizedBox(height: 12),
                      Text('Create a Master Password',
                          textAlign: TextAlign.center,
                          style: context.text.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        'This is the only password you’ll need to remember. It encrypts everything in your vault.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: c.secondaryLabel),
                      ),
                    ],
                  ),
                ),
                InsetSection(
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pw.text.isNotEmpty) ...[
                        StrengthMeter(
                            level: s.level,
                            label: s.warning == null
                                ? s.level.label
                                : '${s.level.label} — ${s.warning}'),
                        const SizedBox(height: 10),
                      ],
                      if (mismatch)
                        Text('Passwords don’t match.',
                            style: TextStyle(color: c.red)),
                    ],
                  ),
                  children: [
                    InputRow(
                      controller: _pw,
                      placeholder: 'Master Password',
                      obscure: _obscure,
                      autofocus: true,
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: (_) => setState(() {}),
                      trailing: IconButton(
                        icon: Icon(
                            _obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                            color: c.gray,
                            size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    InputRow(
                      controller: _confirm,
                      placeholder: 'Verify',
                      obscure: _obscure,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _valid ? _create() : null,
                    ),
                  ],
                ),
                InsetSection(
                  footer: const Text(
                      'A random passphrase of 5 words is strong and easy to remember. Write it down and keep it somewhere safe.'),
                  children: [
                    InsetRow(
                      leading: Icon(CupertinoIcons.wand_stars, color: c.blue),
                      title: const Text('Suggest a Passphrase'),
                      accent: true,
                      onTap: _suggest,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(CupertinoIcons.exclamationmark_triangle_fill,
                            color: c.orange, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Your master password can’t be recovered or reset. If you forget it, the data in this vault is lost.',
                            style: TextStyle(fontSize: 14, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: PillButton(
                    label: widget.restore ? 'Create & Choose Backup' : 'Create Vault',
                    loading: _busy,
                    onPressed: _valid ? _create : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
