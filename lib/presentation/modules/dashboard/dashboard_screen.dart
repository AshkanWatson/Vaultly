import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../logic/providers/app_providers.dart';
import '../../../../data/models/credential_model.dart';
import '../settings/settings_screen.dart';
import 'widgets/credential_tile.dart';
import 'widgets/edit_credential_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentialsAsync = ref.watch(credentialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Vault"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "Sync Now",
            onPressed: () async {
              await ref.read(repositoryProvider).syncData();
              ref.refresh(credentialsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Sync Check Complete")),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Settings",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: credentialsAsync.when(
        data: (creds) {
          if (creds.isEmpty) {
            return const Center(
              child: Text(
                "Vault is empty",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: creds.length,
            itemBuilder: (context, index) {
              final item = creds[index];
              return CredentialTile(
                credential: item,
                onTap: () => _showEditDialog(context, ref, item),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
        onPressed: () => _showEditDialog(context, ref, null),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Credential? item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => EditCredentialSheet(item: item, ref: ref),
    );
  }
}
