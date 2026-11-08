import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../models/models.dart';
import '../../theme/mizani_theme.dart';
import '../../widgets/api_loader.dart';

/// The client's details from `GET /me`, the email change, and sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editEmail(BuildContext context, Client client, VoidCallback saved) async {
    final updated = await showDialog<Client>(
      context: context,
      builder: (_) => _EmailDialog(current: client.email ?? ''),
    );
    if (updated != null && context.mounted) {
      context.read<SessionController>().updateClient(updated);
      saved();
      showMessage(context, 'Email updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return ApiLoader<Client>(
      load: session.repository.me,
      builder: (context, client, reload) {
        const divider = Divider(height: 1, indent: 16, endIndent: 16);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _ProfileHeader(client: client),
            const SizedBox(height: 22),
            const Text('Account details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _InfoRow(icon: Icons.phone_outlined, label: 'Mobile number', value: client.phone),
                  divider,
                  _InfoRow(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    value: client.email,
                    trailing: const Icon(Icons.edit_outlined, size: 18, color: MizaniColors.muted),
                    onTap: () => _editEmail(context, client, reload),
                  ),
                  divider,
                  _InfoRow(icon: Icons.badge_outlined, label: 'National ID', value: client.nationalId),
                  divider,
                  _InfoRow(icon: Icons.receipt_long_outlined, label: 'KRA PIN', value: client.kraPin),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 18, color: MizaniColors.bad),
                label: const Text('Sign out', style: TextStyle(color: MizaniColors.bad)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: MizaniColors.badSoft)),
                onPressed: session.signOut,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog({required this.current});
  final String current;

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  late final _email = TextEditingController(text: widget.current);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = await context.read<SessionController>().repository.updateEmail(_email.text.trim());
      if (mounted) Navigator.of(context).pop(client);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change email'),
      content: TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: 'Email', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}

String _initials(String name) =>
    name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MizaniColors.brand, MizaniColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              _initials(client.name),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            client.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
          ),
          if (client.phone != null) ...[
            const SizedBox(height: 2),
            Text(client.phone!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.value, this.trailing, this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: MizaniColors.muted),
      trailing: trailing,
      title: Text(label, style: const TextStyle(fontSize: 12.5, color: MizaniColors.muted)),
      subtitle: Text(
        (value == null || value!.isEmpty) ? 'Not provided' : value!,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
