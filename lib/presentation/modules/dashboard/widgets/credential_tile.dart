import 'package:flutter/material.dart';
import '../../../common/favicon_widget.dart';
import '../../../../data/models/credential_model.dart';

class CredentialTile extends StatelessWidget {
  final Credential credential;
  final VoidCallback onTap;

  const CredentialTile({
    super.key, 
    required this.credential, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: FaviconWidget(title: credential.title),
        title: Text(credential.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(credential.username),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}