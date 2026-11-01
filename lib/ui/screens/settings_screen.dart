import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/password_strength.dart';
import '../../data/app_settings.dart';
import '../../data/biometric_service.dart';
import '../../data/native_bridge.dart';
import '../../data/vault_envelope.dart';
import '../../state/providers.dart';
import '../actions.dart';
import '../theme/app_theme.dart';
import '../widgets/grouped.dart';
import '../widgets/password_widgets.dart';
import '../widgets/toast.dart';
import '../widgets/vault_page.dart';
import 'import_export.dart';

const appVersion = '2.0.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(settingsProvider);
    final kind = ref.watch(biometricKindProvider).value ?? BiometricKind.none;
    final ctrl = ref.read(vaultProvider.notifier);
    final settings = ref.read(settingsProvider.notifier);
    final isAndroid = !kIsWeb && Platform.isAndroid;

    return VaultPage(
      title: 'Settings',
      slivers: [
        SliverToBoxAdapter(
          child: Column(children: [
            InsetSection(
              header: 'Security',
              dividerIndent: 57,
              children: [
                if (kind != BiometricKind.none)
                  InsetRow(
                    leading: SettingsIcon(
                        kind == BiometricKind.faceId
                            ? Icons.face_unlock_outlined
                            : Icons.fingerprint,
                        c.green),
                    title: Text('Unlock with ${kind.label}'),
                    trailing: CupertinoSwitch(
                      value: s.biometricEnabled,
                      activeTrackColor: c.green,
                      onChanged: (v) async {
                        if (v) {
                          final ok = await AutoLockGuard.run(ctrl.enableBiometrics);
                          if (!ok && context.mounted) {
                            showToast(context, '${kind.label} was not turned on',
                                error: true);
                          }
                        } else {
                          await ctrl.disableBiometrics();
                        }
                      },
                    ),
                  ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.timer, c.blue),
                  title: const Text('Auto-Lock'),
                  value: Text(AppSettings.autoLockChoices[s.autoLockSeconds] ?? ''),
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChoiceScreen<int>(
                      title: 'Auto-Lock',
                      choices: AppSettings.autoLockChoices,
                      selected: s.autoLockSeconds,
                      footer:
                          'Vaultly locks after this much inactivity or time in the background.',
                      onSelected: (v) =>
                          settings.update((x) => x.copyWith(autoLockSeconds: v)),
                    ),
                  )),
                ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.doc_on_clipboard, c.indigo),
                  title: const Text('Clear Clipboard'),
                  value: Text(AppSettings.clipboardChoices[s.clipboardSeconds] ?? ''),
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChoiceScreen<int>(
                      title: 'Clear Clipboard',
                      choices: AppSettings.clipboardChoices,
                      selected: s.clipboardSeconds,
                      footer:
                          'Copied passwords and codes are removed from the clipboard after this delay.',
                      onSelected: (v) =>
                          settings.update((x) => x.copyWith(clipboardSeconds: v)),
                    ),
                  )),
                ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.lock_fill, c.orange),
                  title: const Text('Change Master Password'),
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ChangeMasterPasswordScreen())),
                ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.lock_shield_fill, c.gray),
                  title: const Text('Lock Now'),
                  onTap: () {
                    rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
                    ctrl.lock();
                  },
                ),
              ],
            ),
            InsetSection(
              header: 'Passkeys',
              dividerIndent: 57,
              footer: Text(isAndroid
                  ? 'On Android 14 and later, choose Vaultly under “Passwords, passkeys & accounts” to create and use passkeys in apps and browsers. Passkeys are stored in your encrypted vault and included in backups.'
                  : 'Passkeys are stored in your encrypted vault and included in backups. Using Vaultly as the system passkey provider is currently available on Android 14+.'),
              children: [
                if (isAndroid)
                  InsetRow(
                    leading: SettingsIcon(
                        CupertinoIcons.person_crop_circle_badge_checkmark, c.green),
                    title: const Text('Use Vaultly for Passkeys'),
                    showChevron: true,
                    onTap: () async {
                      if (!await NativeBridge.openPasskeyProviderSettings() &&
                          context.mounted) {
                        showToast(context, 'Requires Android 14 or later', error: true);
                      }
                    },
                  ),
                InsetRow(
                  leading: SettingsIcon(Icons.key_rounded, c.teal),
                  title: const Text('Saved Passkeys'),
                  value: Text('${ref.watch(vaultProvider).items.where(VaultCategory.passkeys.matches).length}'),
                ),
              ],
            ),
            InsetSection(
              header: 'Appearance',
              dividerIndent: 57,
              children: [
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.circle_lefthalf_fill, c.purple),
                  title: const Text('Theme'),
                  value: Text(switch (s.themeMode) {
                    ThemeMode.system => 'Automatic',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  }),
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChoiceScreen<ThemeMode>(
                      title: 'Theme',
                      choices: const {
                        ThemeMode.system: 'Automatic',
                        ThemeMode.light: 'Light',
                        ThemeMode.dark: 'Dark',
                      },
                      selected: s.themeMode,
                      onSelected: (v) =>
                          settings.update((x) => x.copyWith(themeMode: v)),
                    ),
                  )),
                ),
              ],
            ),
            InsetSection(
              header: 'Backup & Transfer',
              dividerIndent: 57,
              footer: const Text(
                  'Encrypted backups (.vaultly) can be restored on any device running Vaultly. CSV import supports Apple Passwords, Chrome, Edge, Firefox, Safari, LastPass, Bitwarden, 1Password, Dashlane and Proton Pass.'),
              children: [
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.arrow_up_doc, c.blue),
                  title: const Text('Export Encrypted Backup'),
                  showChevron: true,
                  onTap: () => exportBackupFlow(context, ref),
                ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.arrow_down_doc, c.green),
                  title: const Text('Restore from Backup'),
                  showChevron: true,
                  onTap: () => importBackupFlow(context, ref),
                ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.square_list_fill, c.orange),
                  title: const Text('Import Passwords from CSV'),
                  showChevron: true,
                  onTap: () => importCsvFlow(context, ref),
                ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.exclamationmark_triangle_fill, c.red),
                  title: const Text('Export Passwords as CSV'),
                  showChevron: true,
                  onTap: () => exportCsvFlow(context, ref),
                ),
              ],
            ),
            InsetSection(
              header: 'About',
              dividerIndent: 57,
              footer: const Text(
                  'Vaultly has no network permission and never connects to the internet. Your master password is never stored; if you forget it, your vault can’t be recovered.'),
              children: [
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.airplane, c.orange),
                  title: const Text('100% Offline'),
                  value: const Text('No network access'),
                ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.lock_shield_fill, c.blue),
                  title: const Text('Encryption'),
                  value: const Text('AES-256-GCM · Argon2id'),
                ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.info, c.gray),
                  title: const Text('Version'),
                  value: const Text(appVersion),
                ),
                InsetRow(
                  leading: SettingsIcon(CupertinoIcons.doc_text_fill, c.gray),
                  title: const Text('Open Source Licenses'),
                  showChevron: true,
                  onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Vaultly',
                      applicationVersion: appVersion),
                ),
              ],
            ),
            InsetSection(children: [
              InsetRow(
                title: const Text('Erase Vault'),
                destructive: true,
                onTap: () => _erase(context, ref),
              ),
            ]),
          ]),
        ),
      ],
    );
  }

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDestructive(context,
        title: 'Erase Vault?',
        message:
            'All passwords, passkeys and notes on this device will be permanently deleted. Export a backup first if you want to keep them.',
        action: 'Erase Everything');
    if (!ok || !context.mounted) return;
    final pw = await promptPassword(context,
        title: 'Master Password', message: 'Confirm to erase.', action: 'Erase');
    if (pw == null || !context.mounted) return;
    final ctrl = ref.read(vaultProvider.notifier);
    if (!await ctrl.verifyMasterPassword(pw)) {
      if (context.mounted) showToast(context, 'Incorrect password', error: true);
      return;
    }
    rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    await ctrl.erase();
  }
}

/// iOS Settings-style single choice list.
class ChoiceScreen<T> extends StatefulWidget {
  const ChoiceScreen({
    super.key,
    required this.title,
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.footer,
  });

  final String title;
  final Map<T, String> choices;
  final T selected;
  final ValueChanged<T> onSelected;
  final String? footer;

  @override
  State<ChoiceScreen<T>> createState() => _ChoiceScreenState<T>();
}

class _ChoiceScreenState<T> extends State<ChoiceScreen<T>> {
  late T _value = widget.selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return VaultPage(
      title: widget.title,
      previousPageTitle: 'Settings',
      largeTitle: false,
      slivers: [
        SliverToBoxAdapter(
          child: InsetSection(
            footer: widget.footer == null ? null : Text(widget.footer!),
            children: [
              for (final e in widget.choices.entries)
                InsetRow(
                  title: Text(e.value),
                  trailing: e.key == _value
                      ? Icon(CupertinoIcons.checkmark_alt, color: c.blue, size: 22)
                      : const SizedBox(width: 22),
                  onTap: () {
                    setState(() => _value = e.key);
                    widget.onSelected(e.key);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ChangeMasterPasswordScreen extends ConsumerStatefulWidget {
  const ChangeMasterPasswordScreen({super.key});

  @override
  ConsumerState<ChangeMasterPasswordScreen> createState() =>
      _ChangeMasterPasswordScreenState();
}

class _ChangeMasterPasswordScreenState
    extends ConsumerState<ChangeMasterPasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      _current.text.isNotEmpty &&
      _next.text.length >= 8 &&
      _next.text == _confirm.text &&
      PasswordStrength.evaluate(_next.text).level.index >=
          StrengthLevel.fair.index;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(vaultProvider.notifier)
          .changeMasterPassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      showToast(context, 'Master password changed');
    } on WrongPasswordException {
      setState(() => _error = 'Current password is incorrect');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = PasswordStrength.evaluate(_next.text);
    void changed(String _) => setState(() {});
    return VaultPage(
      title: 'Master Password',
      previousPageTitle: 'Settings',
      largeTitle: false,
      slivers: [
        SliverToBoxAdapter(
          child: Column(children: [
            InsetSection(
              footer: _error == null ? null : Text(_error!, style: TextStyle(color: c.red)),
              children: [
                InputRow(
                    controller: _current,
                    placeholder: 'Current Password',
                    obscure: true,
                    onChanged: changed),
              ],
            ),
            InsetSection(
              footer: _next.text.isEmpty
                  ? null
                  : StrengthMeter(level: s.level, compact: true, label: s.level.label),
              children: [
                InputRow(
                    controller: _next,
                    placeholder: 'New Password',
                    obscure: true,
                    onChanged: changed),
                InputRow(
                    controller: _confirm,
                    placeholder: 'Verify',
                    obscure: true,
                    onChanged: changed),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PillButton(
                  label: 'Change Password',
                  loading: _busy,
                  onPressed: _valid ? _save : null),
            ),
          ]),
        ),
      ],
    );
  }
}
