import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/vault_envelope.dart';
import '../../state/providers.dart';
import '../actions.dart';
import '../widgets/toast.dart';

String _stamp() {
  final d = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

Future<String?> _pickText() async {
  final files = await AutoLockGuard.run(() => FilePicker.pickFiles());
  if (files.isEmpty) return null;
  final bytes = await files.first.xFile.readAsBytes();
  if (bytes.length > 50 * 1024 * 1024) {
    throw const FormatException('File is too large');
  }
  return utf8.decode(bytes, allowMalformed: false);
}

Future<bool> _save(String name, String contents, String mime) async {
  final uri = await AutoLockGuard.run(() => FilePicker.saveFile(
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(contents)),
        mimeType: mime,
        dialogTitle: 'Save $name',
      ));
  return uri != null;
}

Future<void> exportBackupFlow(BuildContext context, WidgetRef ref) async {
  final password = await promptPassword(
    context,
    title: 'Backup Password',
    message:
        'Choose a password to encrypt this backup. You’ll need it to restore. It can differ from your master password.',
    action: 'Export',
    confirm: true,
  );
  if (password == null || !context.mounted) return;
  try {
    final content =
        await ref.read(vaultProvider.notifier).exportBackup(password);
    final ok = await _save('Vaultly-Backup-${_stamp()}.vaultly', content,
        'application/octet-stream');
    if (ok && context.mounted) showToast(context, 'Backup saved');
  } catch (e) {
    if (context.mounted) showToast(context, 'Export failed: $e', error: true);
  }
}

Future<void> importBackupFlow(BuildContext context, WidgetRef ref) async {
  try {
    final content = await _pickText();
    if (content == null || !context.mounted) return;
    final password = await promptPassword(context,
        title: 'Backup Password',
        message: 'Enter the password this backup was exported with.',
        action: 'Import');
    if (password == null || !context.mounted) return;
    final n =
        await ref.read(vaultProvider.notifier).importBackup(content, password);
    if (context.mounted) {
      showToast(context, n == 0 ? 'Nothing new to import' : 'Imported $n items');
    }
  } on WrongPasswordException {
    if (context.mounted) showToast(context, 'Wrong backup password', error: true);
  } on VaultFormatException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
  } on FormatException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
  }
}

Future<void> importCsvFlow(BuildContext context, WidgetRef ref) async {
  try {
    final content = await _pickText();
    if (content == null || !context.mounted) return;
    final r = await ref.read(vaultProvider.notifier).importCsv(content);
    if (!context.mounted) return;
    await showMessage(
      context,
      'Imported from ${r.source}',
      '${r.added} items imported'
          '${r.skipped > 0 ? ', ${r.skipped} skipped (empty or already in your vault)' : ''}.'
          '\n\nThe CSV file is not encrypted — delete it now.',
    );
  } on FormatException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
  }
}

Future<void> exportCsvFlow(BuildContext context, WidgetRef ref) async {
  final go = await confirmDestructive(
    context,
    title: 'Export Unencrypted CSV?',
    message:
        'Anyone with access to this file can read all of your passwords. Use it only to move to another password manager, then delete it.',
    action: 'Export Passwords',
  );
  if (!go || !context.mounted) return;
  final pw = await promptPassword(context,
      title: 'Master Password', message: 'Confirm it’s you.', action: 'Continue');
  if (pw == null || !context.mounted) return;
  if (!await ref.read(vaultProvider.notifier).verifyMasterPassword(pw)) {
    if (context.mounted) showToast(context, 'Incorrect password', error: true);
    return;
  }
  final csv = ref.read(vaultProvider.notifier).exportCsv();
  final ok = await _save('Vaultly-Passwords-${_stamp()}.csv', csv, 'text/csv');
  if (ok && context.mounted) {
    showToast(context, 'CSV saved', icon: CupertinoIcons.arrow_up_doc);
  }
}
