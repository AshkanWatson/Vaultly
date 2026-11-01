import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/generator/password_generator.dart';
import '../../core/otp/totp.dart';
import '../../data/vault_item.dart';
import '../../data/vault_service.dart';
import '../../state/providers.dart';
import '../actions.dart';
import '../theme/app_theme.dart';
import '../widgets/grouped.dart';
import '../widgets/item_icon.dart';
import '../widgets/password_widgets.dart';
import '../widgets/toast.dart';
import '../widgets/vault_page.dart';
import 'item_edit_screen.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _reveal = false;

  VaultItem? _find(VaultState s) {
    for (final i in s.items) {
      if (i.id == widget.itemId) return i;
    }
    return null;
  }

  void _edit(VaultItem item, {String? newPassword}) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ItemEditScreen(item: item, suggestedPassword: newPassword),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = _find(ref.watch(vaultProvider));
    if (item == null) {
      return Scaffold(
        appBar: CupertinoNavigationBar(
            backgroundColor: c.background, border: null, previousPageTitle: 'Back'),
      );
    }
    final otp = TotpConfig.tryParse(item.otpAuth);
    final issue = ref.watch(securityReportProvider).forItem(item.id);
    final ctrl = ref.read(vaultProvider.notifier);

    return Scaffold(
      appBar: CupertinoNavigationBar(
        backgroundColor: c.background,
        border: null,
        previousPageTitle: 'Back',
        trailing: item.isDeleted
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _edit(item),
                child: const Text('Edit')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            children: [
              InsetSection(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ItemIcon(item: item, size: 60),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.displayTitle,
                                style: context.text.headlineSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('Last modified ${formatDate(item.updatedAt)}',
                                style: TextStyle(
                                    fontSize: 13, color: c.secondaryLabel)),
                          ],
                        ),
                      ),
                      if (item.favorite)
                        Icon(CupertinoIcons.star_fill, color: c.orange, size: 20),
                    ],
                  ),
                ),
              ]),

              if (item.kind != ItemKind.note &&
                  (item.username.isNotEmpty || item.password.isNotEmpty || otp != null))
                InsetSection(children: [
                  if (item.username.isNotEmpty)
                    FieldRow(
                      label: item.kind == ItemKind.wifi ? 'Network Name' : 'User Name',
                      onTap: () => copySecret(context, ref, item.username,
                          what: 'User name copied'),
                      trailing: Icon(CupertinoIcons.doc_on_doc,
                          size: 18, color: c.blue),
                      child: Text(item.username),
                    ),
                  if (item.password.isNotEmpty)
                    FieldRow(
                      label: 'Password',
                      onTap: () => setState(() => _reveal = !_reveal),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: _reveal ? 'Hide' : 'Show',
                          icon: Icon(
                              _reveal ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                              size: 20,
                              color: c.blue),
                          onPressed: () => setState(() => _reveal = !_reveal),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          icon: Icon(CupertinoIcons.doc_on_doc, size: 18, color: c.blue),
                          onPressed: () => copySecret(context, ref, item.password,
                              what: 'Password copied'),
                        ),
                      ]),
                      child: _reveal
                          ? PasswordText(item.password)
                          : Text('•' * item.password.length.clamp(8, 16),
                              style: const TextStyle(letterSpacing: 2)),
                    ),
                  if (otp != null)
                    FieldRow(
                      label: 'Verification Code',
                      onTap: () => copySecret(context, ref, otp.codeAt(DateTime.now()),
                          what: 'Code copied'),
                      trailing: Icon(CupertinoIcons.doc_on_doc, size: 18, color: c.blue),
                      child: OtpCodeView(config: otp),
                    ),
                ]),

              if (issue != null && !item.isDeleted)
                InsetSection(
                  footer: Text(issue.reused
                      ? 'This password is used on ${issue.reusedWith} other ${issue.reusedWith == 1 ? 'account' : 'accounts'}. If one site is breached, the others are at risk.'
                      : 'This password is easy to guess. Change it on the website, then save the new one here.'),
                  children: [
                    InsetRow(
                      leading: Icon(CupertinoIcons.exclamationmark_triangle_fill,
                          color: issue.weak ? c.orange : c.red),
                      title: Text(issue.reused ? 'Reused Password' : 'Weak Password'),
                    ),
                    InsetRow(
                      title: const Text('Change to a Strong Password'),
                      accent: true,
                      onTap: () => _edit(item,
                          newPassword: PasswordGenerator.generate(
                              ref.read(settingsProvider).generator)),
                    ),
                  ],
                ),

              if (item.passkey != null)
                InsetSection(
                  header: 'Passkey',
                  footer: const Text(
                      'Passkeys are a safer replacement for passwords. The private key stays encrypted in your vault.'),
                  children: [
                    InsetRow(
                      leading: Icon(CupertinoIcons.person_crop_circle_badge_checkmark,
                          color: c.green),
                      title: Text(item.passkey!.userName.isEmpty
                          ? item.passkey!.rpId
                          : item.passkey!.userName),
                      subtitle: Text(
                          '${item.passkey!.rpId} · Created ${formatDate(item.passkey!.createdAt)}'
                          '${item.passkey!.lastUsedAt == null ? '' : ' · Used ${formatRelative(item.passkey!.lastUsedAt!)}'}'),
                    ),
                    if (!item.isDeleted)
                      InsetRow(
                        title: const Text('Remove Passkey'),
                        destructive: true,
                        onTap: () async {
                          final ok = await confirmDestructive(context,
                              title: 'Remove Passkey?',
                              message:
                                  'You won’t be able to sign in to ${item.passkey!.rpId} with this passkey anymore.',
                              action: 'Remove Passkey');
                          if (ok) await ctrl.save(item.copyWith(clearPasskey: true));
                        },
                      ),
                  ],
                ),

              if (item.urls.isNotEmpty)
                InsetSection(
                  header: item.urls.length == 1 ? 'Website' : 'Websites',
                  children: [
                    for (final u in item.urls)
                      InsetRow(
                        title: Text(u),
                        accent: true,
                        trailing: Icon(CupertinoIcons.doc_on_doc, size: 18, color: c.blue),
                        onTap: () => copySecret(context, ref, u, what: 'Website copied'),
                      ),
                  ],
                ),

              if (item.notes.isNotEmpty)
                InsetSection(
                  header: item.kind == ItemKind.note ? null : 'Notes',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(item.notes,
                          style: const TextStyle(fontSize: 17, height: 1.35)),
                    ),
                  ],
                ),

              if (item.passwordHistory.isNotEmpty && !item.isDeleted)
                InsetSection(children: [
                  InsetRow(
                    title: const Text('Password History'),
                    value: Text('${item.passwordHistory.length}'),
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PasswordHistoryScreen(item: item))),
                  ),
                ]),

              if (item.isDeleted)
                InsetSection(
                  footer: Text(
                      'This item will be permanently deleted in ${(VaultService.trashRetention.inDays - DateTime.now().difference(item.deletedAt!).inDays).clamp(0, 30)} days.'),
                  children: [
                    InsetRow(
                      title: const Text('Recover'),
                      accent: true,
                      onTap: () async {
                        await ctrl.restore(item.id);
                        if (context.mounted) showToast(context, 'Recovered');
                      },
                    ),
                    InsetRow(
                      title: const Text('Delete Now'),
                      destructive: true,
                      onTap: () async {
                        final ok = await confirmDestructive(context,
                            title: 'Delete Permanently?',
                            message: 'You can’t undo this action.',
                            action: 'Delete');
                        if (!ok) return;
                        await ctrl.deleteForever(item.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                )
              else
                InsetSection(children: [
                  InsetRow(
                    title: Text(item.favorite ? 'Remove from Favorites' : 'Add to Favorites'),
                    accent: true,
                    onTap: () => ctrl.toggleFavorite(item.id),
                  ),
                  InsetRow(
                    title: const Text('Delete'),
                    destructive: true,
                    onTap: () async {
                      final ok = await confirmDestructive(context,
                          title: 'Delete “${item.displayTitle}”?',
                          message: 'It will be kept in Recently Deleted for 30 days.',
                          action: 'Delete');
                      if (!ok) return;
                      await ctrl.moveToTrash(item.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class PasswordHistoryScreen extends ConsumerWidget {
  const PasswordHistoryScreen({super.key, required this.item});
  final VaultItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VaultPage(
      title: 'Password History',
      previousPageTitle: 'Back',
      largeTitle: false,
      slivers: [
        SliverToBoxAdapter(
          child: InsetSection(
            footer: const Text('Previous passwords for this account. Tap to copy.'),
            children: [
              for (final h in item.passwordHistory)
                InsetRow(
                  title: PasswordText(h.password),
                  subtitle: Text('Changed ${formatDate(h.changedAt)}'),
                  onTap: () =>
                      copySecret(context, ref, h.password, what: 'Password copied'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
