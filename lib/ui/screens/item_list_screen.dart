import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/otp/totp.dart';
import '../../data/vault_item.dart';
import '../../data/vault_service.dart';
import '../../state/providers.dart';
import '../actions.dart';
import '../theme/app_theme.dart';
import '../widgets/item_icon.dart';
import '../widgets/vault_page.dart';
import 'home_screen.dart';
import 'item_detail_screen.dart';

enum SortOrder { title, edited, created }

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key, required this.category});
  final VaultCategory category;

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  final _search = TextEditingController();
  String _query = '';
  SortOrder _sort = SortOrder.title;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _isTrash => widget.category == VaultCategory.deleted;

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    var items = searchItems(vault.items.where(widget.category.matches), _query);
    items.sort(switch (_sort) {
      SortOrder.title => (a, b) =>
          a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()),
      SortOrder.edited => (a, b) => b.updatedAt.compareTo(a.updatedAt),
      SortOrder.created => (a, b) => b.createdAt.compareTo(a.createdAt),
    });
    if (_isTrash) {
      items.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    }

    final Widget trailing = _isTrash
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: items.isEmpty
                ? null
                : () async {
                    final ok = await confirmDestructive(context,
                        title: 'Delete All?',
                        message:
                            'These items will be deleted immediately. You can’t undo this action.',
                        action: 'Delete ${items.length} Items');
                    if (ok) await ref.read(vaultProvider.notifier).emptyTrash();
                  },
            child: const Text('Delete All'),
          )
        : PopupMenuButton<SortOrder>(
            icon: const Icon(CupertinoIcons.arrow_up_arrow_down, size: 20),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: SortOrder.title, child: Text('Title')),
              PopupMenuItem(value: SortOrder.edited, child: Text('Date Edited')),
              PopupMenuItem(value: SortOrder.created, child: Text('Date Created')),
            ],
          );

    return VaultPage(
      title: widget.category.title,
      previousPageTitle: 'Passwords',
      search: vaultSearchField(
          context: context,
          controller: _search,
          onChanged: (v) => setState(() => _query = v)),
      trailing: trailing,
      slivers: [
        if (_isTrash)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
              child: Text(
                'Items are permanently deleted after 30 days.',
                style: TextStyle(fontSize: 13, color: context.colors.secondaryLabel),
              ),
            ),
          ),
        if (items.isEmpty)
          SliverToBoxAdapter(child: _empty())
        else
          ...itemListSlivers(context, items,
              grouped: _sort == SortOrder.title && !_isTrash),
      ],
    );
  }

  Widget _empty() {
    final (icon, title, msg) = switch (widget.category) {
      VaultCategory.passkeys => (
          CupertinoIcons.person_crop_circle_badge_checkmark,
          'No Passkeys',
          'Passkeys you create when signing up on websites and apps will appear here.'
        ),
      VaultCategory.codes => (
          CupertinoIcons.clock,
          'No Verification Codes',
          'Add a setup key to a password to generate two-factor codes offline.'
        ),
      VaultCategory.wifi => (CupertinoIcons.wifi, 'No Wi-Fi Networks', null),
      VaultCategory.deleted => (CupertinoIcons.trash, 'No Deleted Items', null),
      VaultCategory.favorites => (
          CupertinoIcons.star,
          'No Favorites',
          'Mark items as favorites to find them quickly.'
        ),
      VaultCategory.notes => (CupertinoIcons.doc_text, 'No Secure Notes', null),
      _ => (
          Icons.key_rounded,
          _query.isEmpty ? 'No Passwords' : 'No Results',
          _query.isEmpty ? 'Tap + to add your first password.' : null
        ),
    };
    return EmptyState(icon: icon, title: title, message: msg);
  }
}

/// Lazily-built inset grouped list of items, optionally sectioned A–Z.
List<Widget> itemListSlivers(BuildContext context, List<VaultItem> items,
    {bool grouped = false}) {
  if (!grouped) return [_section(context, null, items)];
  final sections = <String, List<VaultItem>>{};
  for (final i in items) {
    final first = i.displayTitle.isEmpty ? '#' : i.displayTitle[0].toUpperCase();
    final key = RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
    sections.putIfAbsent(key, () => []).add(i);
  }
  return [for (final e in sections.entries) _section(context, e.key, e.value)];
}

Widget _section(BuildContext context, String? header, List<VaultItem> items) {
  final c = context.colors;
  return SliverMainAxisGroup(slivers: [
    if (header != null)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 4, 32, 6),
          child: Text(header,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.secondaryLabel)),
        ),
      ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final first = i == 0;
          final last = i == items.length - 1;
          return ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: first ? const Radius.circular(12) : Radius.zero,
              bottom: last ? const Radius.circular(12) : Radius.zero,
            ),
            child: ColoredBox(
              color: c.surface,
              child: Column(
                children: [
                  ItemRow(item: items[i]),
                  if (!last)
                    Padding(
                      padding: const EdgeInsets.only(left: 64),
                      child: Container(height: 0.5, color: c.separator),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  ]);
}

class ItemRow extends ConsumerWidget {
  const ItemRow({super.key, required this.item});
  final VaultItem item;

  String _subtitle() {
    if (item.isDeleted) {
      final left = VaultService.trashRetention.inDays -
          DateTime.now().difference(item.deletedAt!).inDays;
      return '${left.clamp(0, 30)} days left';
    }
    return switch (item.kind) {
      ItemKind.note => item.notes.split('\n').first,
      ItemKind.wifi => 'Wi-Fi Network',
      ItemKind.login => item.username.isNotEmpty
          ? item.username
          : item.hasPasskey
              ? 'Passkey'
              : item.hosts.isNotEmpty
                  ? item.hosts.first
                  : '',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sub = _subtitle();
    final row = InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ItemDetailScreen(itemId: item.id))),
      onLongPress: item.isDeleted ? null : () => _quickActions(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            ItemIcon(item: item, size: 38),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(item.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w500)),
                      ),
                      if (item.favorite) ...[
                        const SizedBox(width: 4),
                        Icon(CupertinoIcons.star_fill, size: 12, color: c.orange),
                      ],
                    ],
                  ),
                  if (sub.isNotEmpty)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: c.secondaryLabel)),
                ],
              ),
            ),
            if (item.hasPasskey && !item.isDeleted)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(CupertinoIcons.person_crop_circle_badge_checkmark,
                    size: 16, color: c.tertiaryLabel),
              ),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_right, size: 16, color: c.tertiaryLabel),
          ],
        ),
      ),
    );
    if (item.isDeleted) return row;
    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: c.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Text('Delete',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        await ref.read(vaultProvider.notifier).moveToTrash(item.id);
        messenger.showSnackBar(SnackBar(
          content: Text('“${item.displayTitle}” moved to Recently Deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => ref.read(vaultProvider.notifier).restore(item.id),
          ),
        ));
      },
      child: row,
    );
  }

  Future<void> _quickActions(BuildContext context, WidgetRef ref) async {
    final otp = TotpConfig.tryParse(item.otpAuth);
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(item.displayTitle),
        actions: [
          if (item.username.isNotEmpty)
            CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx, 'user'),
                child: const Text('Copy User Name')),
          if (item.password.isNotEmpty)
            CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx, 'pass'),
                child: const Text('Copy Password')),
          if (otp != null)
            CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx, 'otp'),
                child: const Text('Copy Verification Code')),
          CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, 'fav'),
              child: Text(item.favorite ? 'Remove from Favorites' : 'Add to Favorites')),
          CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Delete')),
        ],
        cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'user':
        await copySecret(context, ref, item.username, what: 'User name copied');
      case 'pass':
        await copySecret(context, ref, item.password, what: 'Password copied');
      case 'otp':
        await copySecret(context, ref, otp!.codeAt(DateTime.now()),
            what: 'Code copied');
      case 'fav':
        await ref.read(vaultProvider.notifier).toggleFavorite(item.id);
      case 'delete':
        await ref.read(vaultProvider.notifier).moveToTrash(item.id);
    }
  }
}
