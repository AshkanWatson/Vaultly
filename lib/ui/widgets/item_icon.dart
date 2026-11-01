import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/vault_item.dart';
import '../theme/app_theme.dart';

/// Offline monogram tile (no favicon downloads — nothing leaves the device).
class ItemIcon extends StatelessWidget {
  const ItemIcon({super.key, required this.item, this.size = 40});

  final VaultItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(size * 0.24);
    if (item.kind == ItemKind.wifi) {
      return _tile(c.blue, radius, Icon(CupertinoIcons.wifi,
          color: Colors.white, size: size * 0.55));
    }
    if (item.kind == ItemKind.note) {
      return _tile(c.yellow, radius, Icon(CupertinoIcons.doc_text_fill,
          color: Colors.white, size: size * 0.5));
    }
    final icon = item.icon;
    if (icon != null) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: c.separator, width: 0.5),
        ),
        child: Image.memory(
          icon,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _monogram(context, c, radius),
        ),
      );
    }
    return _monogram(context, c, radius);
  }

  Widget _monogram(BuildContext context, VColors c, BorderRadius radius) {
    final name = item.displayTitle;
    final hash = name.toLowerCase().codeUnits.fold<int>(7, (h, u) => (h * 31 + u) & 0x7fffffff);
    final color = c.accents[hash % c.accents.length];
    final letters = _letters(name);
    return _tile(
      color,
      radius,
      Text(letters,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * (letters.length > 1 ? 0.36 : 0.46),
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _tile(Color color, BorderRadius radius, Widget child) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.18)!, color],
          ),
        ),
        child: child,
      );

  static String _letters(String name) {
    final words = name
        .replaceAll(RegExp(r'\.(com|org|net|io|app|dev|co)$'), '')
        .split(RegExp(r'[\s._\-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words[0].characters.first + words[1].characters.first)
        .toUpperCase();
  }
}
