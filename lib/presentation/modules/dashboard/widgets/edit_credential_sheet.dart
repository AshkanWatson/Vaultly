import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/credential_model.dart';
import '../../../../data/services/vault_repository.dart';
import '../../../../logic/providers/app_providers.dart';

class EditCredentialSheet extends StatefulWidget {
  final Credential? item;
  final WidgetRef ref;

  const EditCredentialSheet({super.key, this.item, required this.ref});

  @override
  State<EditCredentialSheet> createState() => _EditCredentialSheetState();
}

class _EditCredentialSheetState extends State<EditCredentialSheet> {
  late TextEditingController titleCtrl;
  late TextEditingController userCtrl;
  late TextEditingController passCtrl;
  bool isPassVisible = false;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.item?.title);
    userCtrl = TextEditingController(text: widget.item?.username);
    passCtrl = TextEditingController(text: widget.item?.password);
  }

  void _copyToClipboard(String value, String type) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$type copied! Clipboard clears in 30s.")));
    Future.delayed(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  void _save() async {
    await widget.ref.read(repositoryProvider).saveCredential(
        widget.item?.id, titleCtrl.text, userCtrl.text, passCtrl.text);
    widget.ref.refresh(credentialsProvider);
    if (mounted) Navigator.pop(context);
  }

  void _delete() async {
    await widget.ref.read(repositoryProvider).deleteCredential(widget.item!.id);
    widget.ref.refresh(credentialsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.item == null ? "Add Credential" : "Edit Credential",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              if (widget.item == null)
                TextButton.icon(
                  icon: const Icon(Icons.casino, size: 18),
                  label: const Text("Generate Password"),
                  onPressed: () {
                    final newPass = VaultRepository.generatePassword();
                    passCtrl.text = newPass;
                    setState(() {});
                  },
                )
            ],
          ),
          const SizedBox(height: 15),
          TextField(
              controller: titleCtrl,
              decoration:
                  const InputDecoration(labelText: 'Title (e.g. Netflix)')),
          const SizedBox(height: 10),
          TextField(
              controller: userCtrl,
              decoration: InputDecoration(
                labelText: 'Username',
                suffixIcon: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () =>
                        _copyToClipboard(userCtrl.text, "Username")),
              )),
          const SizedBox(height: 10),
          TextField(
              controller: passCtrl,
              obscureText: !isPassVisible,
              decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(isPassVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => isPassVisible = !isPassVisible),
                      ),
                      IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () =>
                              _copyToClipboard(passCtrl.text, "Password")),
                    ],
                  ))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.item != null)
                TextButton(
                  onPressed: _delete,
                  child:
                      const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _save,
                child: const Text("Save"),
              ),
            ],
          )
        ],
      ),
    );
  }
}
