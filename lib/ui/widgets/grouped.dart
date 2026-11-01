import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// iOS "inset grouped" section: rounded card with hairline separators.
class InsetSection extends StatelessWidget {
  const InsetSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.dividerIndent = 16,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 24),
  });

  final List<Widget> children;
  final String? header;
  final Widget? footer;
  final double dividerIndent;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: EdgeInsetsDirectional.only(start: dividerIndent),
          child: Container(height: 0.5, color: c.separator),
        ));
      }
    }
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(header!.toUpperCase(),
                  style: TextStyle(
                      fontSize: 13,
                      color: c.secondaryLabel,
                      letterSpacing: -0.08)),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: c.surface,
              child: Column(children: rows),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                    fontSize: 13, color: c.secondaryLabel, height: 1.3),
                child: footer!,
              ),
            ),
        ],
      ),
    );
  }
}

/// A row inside an [InsetSection].
class InsetRow extends StatelessWidget {
  const InsetRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showChevron = false,
    this.destructive = false,
    this.accent = false,
    this.titleStyle,
    this.minHeight = 44,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showChevron;
  final bool destructive;
  final bool accent;
  final TextStyle? titleStyle;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = destructive
        ? c.red
        : accent
            ? c.blue
            : c.label;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DefaultTextStyle.merge(
                      style: titleStyle ??
                          TextStyle(
                              fontSize: 17,
                              color: color,
                              letterSpacing: -0.41),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle.merge(
                        style: TextStyle(
                            fontSize: 15,
                            color: c.secondaryLabel,
                            letterSpacing: -0.24),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(fontSize: 17, color: c.secondaryLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        child: value!,
                      ),
                    ),
                  ),
                ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (showChevron) ...[
                const SizedBox(width: 6),
                Icon(CupertinoIcons.chevron_right,
                    size: 17, color: c.tertiaryLabel),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Labelled row showing a stored value, iOS detail style (small label above,
/// value below). Tap to copy is handled by the caller.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final String label;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 13, color: c.secondaryLabel)),
                  const SizedBox(height: 3),
                  DefaultTextStyle.merge(
                    style: TextStyle(fontSize: 17, color: c.label),
                    child: child,
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Text input row for edit forms.
class InputRow extends StatelessWidget {
  const InputRow({
    super.key,
    required this.controller,
    required this.placeholder,
    this.label,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.trailing,
    this.onChanged,
    this.maxLines = 1,
    this.monospace = false,
    this.autofocus = false,
    this.focusNode,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String placeholder;
  final String? label;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final bool monospace;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
      child: Row(
        crossAxisAlignment:
            maxLines == 1 ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (label != null)
            SizedBox(
              width: 104,
              child: Text(label!,
                  style: TextStyle(fontSize: 17, color: c.label)),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              obscureText: obscure,
              enableSuggestions: !obscure && !monospace,
              autocorrect: false,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              textCapitalization: textCapitalization,
              autofillHints: autofillHints,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              maxLines: obscure ? 1 : maxLines,
              minLines: maxLines == null ? 4 : null,
              style: TextStyle(
                fontSize: 17,
                color: c.label,
                fontFamily: monospace ? 'monospace' : null,
                fontFamilyFallback: monospace
                    ? const ['Menlo', 'Courier New', 'Roboto Mono']
                    : null,
              ),
              decoration: InputDecoration.collapsed(
                hintText: placeholder,
                hintStyle: TextStyle(color: c.tertiaryLabel, fontSize: 17),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// Large rounded iOS-style filled button.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tinted = false,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool tinted;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = color ?? c.blue;
    final bg = tinted ? base.withValues(alpha: 0.15) : base;
    final fg = tinted ? base : Colors.white;
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: onPressed == null ? c.fill : bg,
          foregroundColor: fg,
          disabledForegroundColor: c.tertiaryLabel,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: context.text.bodyLarge
              ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CupertinoActivityIndicator(color: fg))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) Icon(icon, size: 20),
                  if (icon != null && label.isNotEmpty) const SizedBox(width: 8),
                  if (label.isNotEmpty)
                    Flexible(
                      child: Text(label,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Small coloured rounded-square icon used in settings rows.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, this.color, {super.key});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 18, color: Colors.white),
      );
}
