import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/vault_item.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_page.dart';
import 'item_edit_screen.dart';
import 'item_list_screen.dart';
import 'security_screen.dart';

/// "Passwords" home: search + category tiles (like Apple Passwords).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vault = ref.watch(vaultProvider);
    final security = ref.watch(securityReportProvider);
    int count(VaultCategory cat) => vault.items.where(cat.matches).length;

    final tiles = <(VaultCategory, IconData, Color, int)>[
      (VaultCategory.all, Icons.key_rounded, c.blue, count(VaultCategory.all)),
      (VaultCategory.passkeys, CupertinoIcons.person_crop_circle_badge_checkmark,
          c.green, count(VaultCategory.passkeys)),
      (VaultCategory.codes, CupertinoIcons.clock_fill, c.indigo,
          count(VaultCategory.codes)),
      (VaultCategory.wifi, CupertinoIcons.wifi, c.teal, count(VaultCategory.wifi)),
      (
        VaultCategory.security,
        security.count == 0
            ? CupertinoIcons.checkmark_shield_fill
            : CupertinoIcons.exclamationmark_shield_fill,
        security.count == 0 ? c.green : c.red,
        security.count
      ),
      (VaultCategory.deleted, CupertinoIcons.trash_fill, c.gray,
          count(VaultCategory.deleted)),
      (VaultCategory.favorites, CupertinoIcons.star_fill, c.orange,
          count(VaultCategory.favorites)),
      (VaultCategory.notes, CupertinoIcons.doc_text_fill, c.yellow,
          count(VaultCategory.notes)),
    ];

    final results = _query.isEmpty
        ? const <VaultItem>[]
        : (searchItems(vault.active, _query)
          ..sort((a, b) => a.displayTitle
              .toLowerCase()
              .compareTo(b.displayTitle.toLowerCase())));

    return VaultPage(
      title: 'Passwords',
      search: vaultSearchField(
        context: context,
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => showNewItemSheet(context),
        child: const Icon(CupertinoIcons.plus, size: 26),
      ),
      slivers: _query.isNotEmpty
          ? [
              if (results.isEmpty)
                SliverToBoxAdapter(
                    child: EmptyState(
                  icon: CupertinoIcons.search,
                  title: 'No Results',
                  message: 'No items match “$_query”.',
                ))
              else
                ...itemListSlivers(context, results),
            ]
          : [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(builder: (context, cons) {
                  final cols = cons.crossAxisExtent >= 600 ? 4 : 2;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 92,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: tiles.length,
                      (context, i) {
                        final (cat, icon, color, n) = tiles[i];
                        return CategoryTile(
                          title: cat.title,
                          icon: icon,
                          color: color,
                          count: n,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => cat == VaultCategory.security
                                  ? const SecurityScreen()
                                  : ItemListScreen(category: cat),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.lock_fill,
                          size: 13, color: c.tertiaryLabel),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${vault.active.length} items · encrypted on this device only',
                          style:
                              TextStyle(fontSize: 13, color: c.tertiaryLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 19),
                  ),
                  const Spacer(),
                  Text('$count',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
              const Spacer(),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.secondaryLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
      child: Column(
        children: [
          Icon(icon, size: 52, color: c.tertiaryLabel),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: c.secondaryLabel)),
          ],
        ],
      ),
    );
  }
}

/// "+" menu: what kind of item to create.
Future<void> showNewItemSheet(BuildContext context) async {
  final kind = await showCupertinoModalPopup<ItemKind>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        for (final k in ItemKind.values)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, k),
            child: Text('New ${k.label}'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (kind == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ItemEditScreen(kind: kind),
  ));
}
