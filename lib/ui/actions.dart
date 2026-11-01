import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/native_bridge.dart';
import '../state/providers.dart';
import 'theme/app_theme.dart';
import 'widgets/toast.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Suspends auto-lock while a system UI the app opened (file picker, share
/// sheet, biometric prompt) temporarily backgrounds Vaultly.
class AutoLockGuard {
  AutoLockGuard._();
  static int _depth = 0;
  static bool get active => _depth > 0;

  static Future<T> run<T>(Future<T> Function() f) async {
    _depth++;
    try {
      return await f();
    } finally {
      // Lifecycle "resumed" arrives just after the system UI closes.
      Future<void>.delayed(const Duration(seconds: 1), () => _depth--);
    }
  }
}

/// Copies a secret, then clears the clipboard after the configured delay
/// (only if the clipboard still holds what we copied).
Future<void> copySecret(BuildContext context, WidgetRef ref, String value,
    {String what = 'Copied'}) async {
  await NativeBridge.copySensitive(value);
  final seconds = ref.read(settingsProvider).clipboardSeconds;
  if (context.mounted) {
    showToast(context, seconds > 0 ? '$what · clears in ${_dur(seconds)}' : what,
        icon: CupertinoIcons.doc_on_doc);
  }
  if (seconds > 0) {
    Timer(Duration(seconds: seconds),
        () => NativeBridge.clearClipboardIfUnchanged(value));
  }
}

String _dur(int s) => s < 60 ? '${s}s' : '${s ~/ 60} min';

/// iOS action-sheet confirmation for destructive actions.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
}) async {
  final r = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title),
      message: message == null ? null : Text(message),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx, false),
        child: const Text('Cancel'),
      ),
    ),
  );
  return r ?? false;
}

/// Asks for a password in an iOS-style alert. Returns null on cancel.
Future<String?> promptPassword(
  BuildContext context, {
  required String title,
  String? message,
  String action = 'OK',
  bool confirm = false,
}) {
  return showCupertinoDialog<String>(
    context: context,
    builder: (ctx) => _PasswordPrompt(
        title: title, message: message, action: action, confirm: confirm),
  );
}

class _PasswordPrompt extends StatefulWidget {
  const _PasswordPrompt({
    required this.title,
    required this.message,
    required this.action,
    required this.confirm,
  });

  final String title;
  final String? message;
  final String action;
  final bool confirm;

  @override
  State<_PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<_PasswordPrompt> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _submit() {
    if (_a.text.isEmpty) return;
    if (widget.confirm && _a.text != _b.text) {
      setState(() => _error = 'Passwords don’t match');
      return;
    }
    Navigator.pop(context, _a.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Column(
        children: [
          if (widget.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(widget.message!),
            ),
          CupertinoTextField(
            controller: _a,
            obscureText: true,
            autofocus: true,
            placeholder: 'Password',
            onSubmitted: (_) => widget.confirm ? null : _submit(),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _b,
              obscureText: true,
              placeholder: 'Verify',
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: c.red, fontSize: 13)),
            ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

Future<void> showMessage(BuildContext context, String title, String message) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );

String formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String formatRelative(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatDate(d);
}
