import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../logic/providers/app_providers.dart';

const secureStorage = FlutterSecureStorage();

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Security",
                  style: TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.bold))),
          const ListTile(
            leading: Icon(Icons.timer),
            title: Text("Auto-Lock"),
            subtitle: Text("Vault locks after 2 minutes of inactivity"),
            trailing: Icon(Icons.check_circle, color: Colors.teal),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text("Clear Biometric Data"),
            subtitle: const Text("Disable biometric unlock for this device"),
            onTap: () async {
              await secureStorage.delete(key: 'vault_master_pass');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Biometric data cleared.")));
              }
            },
          ),
          const Divider(),
          const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Appearance",
                  style: TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.bold))),
          RadioListTile<ThemeMode>(
            title: const Text("System Default"),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (val) =>
                ref.read(themeModeProvider.notifier).state = val!,
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Dark Mode"),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (val) =>
                ref.read(themeModeProvider.notifier).state = val!,
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Light Mode"),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (val) =>
                ref.read(themeModeProvider.notifier).state = val!,
          ),
          const Divider(),
          const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Data Management",
                  style: TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text("Export Vault"),
            subtitle: const Text("Share to Save (Drive, Files, WhatsApp)"),
            onTap: () => _handleExport(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text("Import Vault"),
            subtitle: const Text("Restore from .vaultly file"),
            onTap: () => _handleImport(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final passCtrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create Backup Password"),
        content: TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Backup Password")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, passCtrl.text),
              child: const Text("Continue")),
        ],
      ),
    );

    if (password == null || password.isEmpty) return;

    try {
      final encryptedData =
          await ref.read(repositoryProvider).exportVaultToString(password);

      final directory = await getTemporaryDirectory();
      final tempFile = File('${directory.path}/vaultly_backup.vaultly');
      await tempFile.writeAsString(encryptedData, flush: true);

      if (await tempFile.length() == 0) {
        throw Exception("System failed to generate backup file.");
      }

      if (!context.mounted) return;

      await Share.shareXFiles(
        [XFile(tempFile.path, mimeType: 'application/octet-stream')],
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Export Failed: $e")));
      }
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        final passCtrl = TextEditingController();
        // ignore: use_build_context_synchronously
        final password = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Enter Backup Password"),
            content: TextField(
                controller: passCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: "Backup Password")),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, passCtrl.text),
                  child: const Text("Import")),
            ],
          ),
        );

        if (password != null && password.isNotEmpty) {
          try {
            await ref
                .read(repositoryProvider)
                .importVaultFromString(content, password);
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Import Successful!")));
            ref.refresh(credentialsProvider);
          } catch (error) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(error.toString().replaceAll("Exception:", ""))));
          }
        }
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("System Error: $e")));
    }
  }
}
