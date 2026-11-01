import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Max readable width for content on tablets / desktop.
const double kContentMaxWidth = 720;

/// Page with an iOS large-title navigation bar that collapses on scroll,
/// optional integrated search field, and width-constrained content.
class VaultPage extends StatelessWidget {
  const VaultPage({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.leading,
    this.search,
    this.previousPageTitle,
    this.largeTitle = true,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? trailing;
  final Widget? leading;
  final CupertinoSearchTextField? search;
  final String? previousPageTitle;
  final bool largeTitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bar = search != null
        ? CupertinoSliverNavigationBar.search(
            searchField: search!,
            largeTitle: Text(title),
            trailing: trailing,
            leading: leading,
            previousPageTitle: previousPageTitle,
            backgroundColor: c.background.withValues(alpha: 0.9),
            border: null,
            heroTag: 'nav-$title',
          )
        : largeTitle
            ? CupertinoSliverNavigationBar(
                largeTitle: Text(title),
                trailing: trailing,
                leading: leading,
                previousPageTitle: previousPageTitle,
                backgroundColor: c.background.withValues(alpha: 0.9),
                border: null,
                heroTag: 'nav-$title',
              )
            : SliverToBoxAdapter(
                child: CupertinoNavigationBar(
                  middle: Text(title),
                  trailing: trailing,
                  leading: leading,
                  previousPageTitle: previousPageTitle,
                  backgroundColor: c.background,
                  border: null,
                  heroTag: 'nav-$title',
                  transitionBetweenRoutes: false,
                ),
              );
    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          bar,
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          for (final s in slivers)
            SliverCrossAxisConstrained(maxCrossAxisExtent: kContentMaxWidth, sliver: s),
          SliverToBoxAdapter(
              child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 24)),
        ],
      ),
    );
  }
}

/// Centres a sliver and limits its width on large screens.
class SliverCrossAxisConstrained extends StatelessWidget {
  const SliverCrossAxisConstrained(
      {super.key, required this.maxCrossAxisExtent, required this.sliver});

  final double maxCrossAxisExtent;
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(builder: (context, constraints) {
      final w = constraints.crossAxisExtent;
      final pad = w > maxCrossAxisExtent ? (w - maxCrossAxisExtent) / 2 : 0.0;
      return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad), sliver: sliver);
    });
  }
}

/// iOS search field styled for the current theme.
CupertinoSearchTextField vaultSearchField({
  required BuildContext context,
  required TextEditingController controller,
  required ValueChanged<String> onChanged,
  String placeholder = 'Search',
  FocusNode? focusNode,
}) =>
    CupertinoSearchTextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      placeholder: placeholder,
      autocorrect: false,
      style: TextStyle(color: context.colors.label),
      backgroundColor: context.colors.fill,
    );
