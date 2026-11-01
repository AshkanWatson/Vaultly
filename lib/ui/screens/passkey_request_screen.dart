import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/passkey/webauthn.dart';
import '../../data/native_bridge.dart';
import '../../data/vault_item.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/grouped.dart';
import '../widgets/item_icon.dart';

/// Shown when Android's Credential Manager opens Vaultly to create or use a
/// passkey. The vault is already unlocked at this point.
class PasskeyRequestScreen extends ConsumerStatefulWidget {
  const PasskeyRequestScreen({super.key, required this.request});
  final PasskeyRequest request;

  @override
  ConsumerState<PasskeyRequestScreen> createState() =>
      _PasskeyRequestScreenState();
}

class _PasskeyRequestScreenState extends ConsumerState<PasskeyRequestScreen> {
  bool _busy = false;
  String? _error;

  PasskeyRequest get r => widget.request;

  @override
  void initState() {
    super.initState();
    // "Unlock" requests only needed the vault opened; the provider service
    // now lists the passkeys itself.
    if (r.type == 'unlock') {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => NativeBridge.completeUnlock());
    }
  }

  Future<void> _run(Future<String> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await NativeBridge.completePasskeyRequest(await f());
    } on WebAuthnException catch (e) {
      setState(() => _error = e.message);
    } on FormatException {
      setState(() => _error = 'The request from this app is not valid.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = ref.read(vaultProvider.notifier);

    String rpId;
    String user = '';
    List<VaultItem> candidates = const [];
    try {
      if (r.type == 'create') {
        final req = CreationRequest.fromJson(r.requestJson);
        rpId = req.rpId;
        user = req.userName;
      } else {
        final req = AssertionRequest.fromJson(r.requestJson);
        rpId = req.rpId;
        candidates = ref
            .watch(vaultProvider)
            .active
            .where((i) => i.passkey != null && req.allows(i.passkey!))
            .toList();
        if (r.itemId != null) {
          candidates = candidates.where((i) => i.id == r.itemId).toList();
        }
      }
    } catch (_) {
      rpId = '';
    }

    final Widget body;
    if (r.type == 'unlock') {
      body = const Center(child: CupertinoActivityIndicator());
    } else if (r.type == 'create') {
      body = Column(children: [
        Icon(CupertinoIcons.person_crop_circle_badge_checkmark, size: 64, color: c.green),
        const SizedBox(height: 16),
        Text('Save a Passkey?', style: context.text.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'A passkey for “$user” will be saved in Vaultly and used to sign in to $rpId.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: c.secondaryLabel),
        ),
        const SizedBox(height: 28),
        PillButton(
          label: 'Save Passkey',
          loading: _busy,
          onPressed: rpId.isEmpty
              ? null
              : () => _run(() async => (await ctrl.registerPasskey(r)).$2),
        ),
      ]);
    } else {
      body = Column(children: [
        Icon(CupertinoIcons.person_crop_circle_badge_checkmark, size: 64, color: c.blue),
        const SizedBox(height: 16),
        Text('Sign In with a Passkey', style: context.text.headlineSmall),
        const SizedBox(height: 8),
        Text(rpId, style: TextStyle(fontSize: 15, color: c.secondaryLabel)),
        const SizedBox(height: 24),
        if (candidates.isEmpty)
          Text('No saved passkey for this website.',
              style: TextStyle(color: c.secondaryLabel))
        else
          InsetSection(
            margin: EdgeInsets.zero,
            children: [
              for (final i in candidates)
                InsetRow(
                  leading: ItemIcon(item: i, size: 34),
                  title: Text(i.passkey!.userName.isEmpty ? i.displayTitle : i.passkey!.userName),
                  subtitle: Text(i.passkey!.rpId),
                  showChevron: true,
                  onTap: _busy ? null : () => _run(() => ctrl.assertPasskey(i.id, r)),
                ),
            ],
          ),
      ]);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(children: [
                body,
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.red)),
                ],
                if (r.type != 'unlock') ...[
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: () => NativeBridge.cancelPasskeyRequest(_error),
                    child: const Text('Cancel'),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
