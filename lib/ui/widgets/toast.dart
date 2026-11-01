import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

OverlayEntry? _current;

/// iOS-style HUD toast ("Copied", "Saved", …).
void showToast(BuildContext context, String message,
    {IconData icon = CupertinoIcons.checkmark_alt, bool error = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  final c = context.colors;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _Toast(
      message: message,
      icon: error ? CupertinoIcons.exclamationmark_triangle_fill : icon,
      color: error ? c.red : c.label,
      background: c.surfaceHigh,
      onDone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.icon,
    required this.color,
    required this.background,
    required this.onDone,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _ctrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + 96;
    return Positioned(
      left: 24,
      right: 24,
      bottom: bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _ctrl,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack)),
            child: Center(
              child: Material(
                color: widget.background,
                elevation: 8,
                shadowColor: Colors.black38,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 18, color: widget.color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(widget.message,
                            style: TextStyle(
                                color: widget.color,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
