import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/security_audit.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/grouped.dart';
import '../widgets/item_icon.dart';
import '../widgets/vault_page.dart';
import 'item_detail_screen.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final report = ref.watch(securityReportProvider);
    final ok = report.count == 0;

    Widget row(SecurityIssue i, String subtitle) => InsetRow(
          leading: ItemIcon(item: i.item, size: 34),
          title: Text(i.item.displayTitle),
          subtitle: Text(subtitle),
          showChevron: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ItemDetailScreen(itemId: i.item.id))),
        );

    return VaultPage(
      title: 'Security',
      previousPageTitle: 'Passwords',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Icon(
                    ok
                        ? CupertinoIcons.checkmark_shield_fill
                        : CupertinoIcons.exclamationmark_shield_fill,
                    size: 56,
                    color: ok ? c.green : c.red),
                const SizedBox(height: 10),
                Text(
                    ok
                        ? 'No Issues Found'
                        : '${report.count} Security Recommendation${report.count == 1 ? '' : 's'}',
                    style: context.text.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Vaultly checks your passwords for weaknesses and reuse on this device. Nothing is ever sent online.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: c.secondaryLabel),
                ),
              ]),
            ),
          ),
        ),
        if (report.reused.isNotEmpty)
          SliverToBoxAdapter(
            child: InsetSection(
              header: 'Reused Passwords',
              dividerIndent: 62,
              footer: const Text(
                  'If one of these websites is breached, attackers can use the same password on the others.'),
              children: [
                for (final i in report.reused)
                  row(i,
                      'Also used on ${i.reusedWith} other account${i.reusedWith == 1 ? '' : 's'}'),
              ],
            ),
          ),
        if (report.weak.isNotEmpty)
          SliverToBoxAdapter(
            child: InsetSection(
              header: 'Weak Passwords',
              dividerIndent: 62,
              footer: const Text(
                  'These passwords are easy to guess. Change them using the generator.'),
              children: [for (final i in report.weak) row(i, 'Easily guessed')],
            ),
          ),
      ],
    );
  }
}
