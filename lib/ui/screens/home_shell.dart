import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'generator_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Mobile-first shell: iOS tab bar on phones, a sidebar on tablets/desktop.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    (CupertinoIcons.lock_shield_fill, 'Passwords'),
    (CupertinoIcons.wand_stars, 'Generator'),
    (CupertinoIcons.gear_solid, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = IndexedStack(
      index: _index,
      children: const [HomeScreen(), GeneratorScreen(), SettingsScreen()],
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 840) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: constraints.maxWidth >= 1100,
                minExtendedWidth: 220,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: constraints.maxWidth >= 1100
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: const SizedBox(height: 12),
                destinations: [
                  for (final t in _tabs)
                    NavigationRailDestination(
                        icon: Icon(t.$1), label: Text(t.$2)),
                ],
              ),
              Container(width: 0.5, color: c.separator),
              Expanded(child: body),
            ],
          ),
        );
      }
      return Scaffold(
        body: body,
        bottomNavigationBar: CupertinoTabBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          activeColor: c.blue,
          inactiveColor: c.gray,
          backgroundColor: c.surface.withValues(alpha: 0.92),
          border: Border(top: BorderSide(color: c.separator, width: 0.5)),
          items: [
            for (final t in _tabs)
              BottomNavigationBarItem(icon: Icon(t.$1), label: t.$2),
          ],
        ),
      );
    });
  }
}
