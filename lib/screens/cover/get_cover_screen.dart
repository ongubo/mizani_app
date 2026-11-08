import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../models/models.dart';
import '../../theme/mizani_theme.dart';
import '../../widgets/api_loader.dart';
import 'proposal_form_screen.dart';

/// Apply direct: choose a cover, then an underwriter selling it.
class GetCoverScreen extends StatelessWidget {
  const GetCoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SessionController>().repository;
    return Scaffold(
      appBar: AppBar(title: const Text('Get cover')),
      body: ApiLoader<List<CoverType>>(
        load: repository.coverTypes,
        builder: (context, covers, reload) {
          if (covers.isEmpty) {
            return const MessageView(
              icon: Icons.shield_outlined,
              color: MizaniColors.muted,
              title: 'No cover available yet',
              body: 'Please check back soon.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'What would you like to cover?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...covers.map(
                (cover) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined, color: MizaniColors.brand),
                    title: Text(cover.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: MizaniColors.muted),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => _UnderwriterScreen(cover: cover)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UnderwriterScreen extends StatefulWidget {
  const _UnderwriterScreen({required this.cover});
  final CoverType cover;

  @override
  State<_UnderwriterScreen> createState() => _UnderwriterScreenState();
}

class _UnderwriterScreenState extends State<_UnderwriterScreen> {
  String? _startingId;

  Future<void> _start(Underwriter underwriter) async {
    setState(() => _startingId = underwriter.id);
    final session = context.read<SessionController>();
    try {
      final proposal = await session.repository.startProposal(
        coverKey: widget.cover.key,
        underwriterId: underwriter.id,
      );
      if (!mounted) return;
      session.dataChanged();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ProposalFormScreen(proposalId: proposal.id)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _startingId = null);
        showMessage(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SessionController>().repository;
    return Scaffold(
      appBar: AppBar(title: Text(widget.cover.name)),
      body: ApiLoader<List<Underwriter>>(
        load: () => repository.underwriters(widget.cover.key),
        builder: (context, underwriters, reload) {
          if (underwriters.isEmpty) {
            return const MessageView(
              icon: Icons.storefront_outlined,
              color: MizaniColors.muted,
              title: 'No insurers yet',
              body: 'No insurer is offering this cover directly at the moment.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Choose an insurer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...underwriters.map(
                (underwriter) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(underwriter.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: _startingId == underwriter.id
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right, color: MizaniColors.muted),
                    onTap: _startingId == null ? () => _start(underwriter) : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
