import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/session.dart';
import '../../models/models.dart';
import '../../theme/mizani_theme.dart';
import '../../widgets/api_loader.dart';
import 'get_cover_screen.dart';
import 'proposal_form_screen.dart';
import 'quotes_screen.dart';

/// Every application the client has made, from `GET /proposals`.
class ProposalsScreen extends StatelessWidget {
  const ProposalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return ApiLoader<List<Proposal>>(
      load: session.repository.proposals,
      builder: (context, proposals, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My cover', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GetCoverScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (proposals.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No applications yet. Tap New to get cover.',
                    style: TextStyle(color: MizaniColors.muted),
                  ),
                ),
              )
            else
              ...proposals.map((p) => ProposalCard(proposal: p)),
          ],
        ),
      ),
    );
  }
}

/// One application. Tapping goes wherever its status allows.
class ProposalCard extends StatelessWidget {
  const ProposalCard({super.key, required this.proposal, this.highlight = false});

  final Proposal proposal;
  final bool highlight;

  void _open(BuildContext context) {
    final Widget? next = switch (proposal.status) {
      ProposalStatus.draft => ProposalFormScreen(proposalId: proposal.id),
      ProposalStatus.quotesShared || ProposalStatus.accepted => QuotesScreen(
          proposalId: proposal.id,
          coverName: proposal.coverType.name,
        ),
      _ => null,
    };

    if (next == null) {
      showMessage(
        context,
        proposal.status == ProposalStatus.declined
            ? 'The insurer could not offer a quote on this application.'
            : "We'll let you know as soon as your quotes are ready.",
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final (color, soft) = switch (proposal.status) {
      ProposalStatus.accepted => (MizaniColors.ok, MizaniColors.okSoft),
      ProposalStatus.declined => (MizaniColors.bad, MizaniColors.badSoft),
      ProposalStatus.quotesShared => (MizaniColors.info, MizaniColors.infoSoft),
      ProposalStatus.quoting || ProposalStatus.submitted => (MizaniColors.warn, MizaniColors.warnSoft),
      _ => (MizaniColors.muted, MizaniColors.surface),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: highlight ? MizaniColors.infoSoft : null,
      child: ListTile(
        onTap: () => _open(context),
        title: Text(proposal.coverType.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            proposal.partnerName,
            if (proposal.submittedAt != null) 'sent ${formatDate(proposal.submittedAt!)}',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(999)),
          child: Text(
            proposal.statusLabel,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ),
    );
  }
}
