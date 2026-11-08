import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../models/models.dart';
import '../../theme/mizani_theme.dart';
import '../../widgets/api_loader.dart';
import '../cover/get_cover_screen.dart';
import '../cover/proposal_form_screen.dart';
import '../cover/proposals_screen.dart';

/// What needs the client's attention, from `GET /home`.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionController>();
    return ApiLoader<HomeSummary>(
      load: session.repository.home,
      builder: (context, home, reload) {
        final invitations = home.openInvitations;
        final ready = home.openProposals.where((p) => p.status == ProposalStatus.quotesShared);
        final drafts = home.openProposals.where(
          (p) =>
              p.status == ProposalStatus.draft &&
              !invitations.any(
                (i) => i.partnerName == p.partnerName && i.coverType.key == p.coverType.key,
              ),
        );
        final waiting = home.openProposals.where(
          (p) => p.status == ProposalStatus.submitted || p.status == ProposalStatus.quoting,
        );
        final declined = home.openProposals.where((p) => p.status == ProposalStatus.declined);
        final isEmpty = invitations.isEmpty && home.openProposals.isEmpty;

        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Habari, ${home.client.firstName}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Get cover'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GetCoverScreen()),
                  ),
                ),
              ),
              if (ready.isNotEmpty) ...[
                const _SectionTitle('Quotes ready'),
                ...ready.map((p) => ProposalCard(proposal: p, highlight: true)),
              ],
              if (invitations.isNotEmpty) ...[
                const _SectionTitle('Invitations'),
                ...invitations.map((i) => _InvitationCard(invitation: i)),
              ],
              if (drafts.isNotEmpty) ...[
                const _SectionTitle('Continue your application'),
                ...drafts.map((p) => ProposalCard(proposal: p)),
              ],
              if (waiting.isNotEmpty) ...[
                const _SectionTitle('Waiting for quotes'),
                ...waiting.map((p) => ProposalCard(proposal: p)),
              ],
              if (declined.isNotEmpty) ...[
                const _SectionTitle('Could not be quoted'),
                ...declined.map((p) => ProposalCard(proposal: p)),
              ],
              if (isEmpty) ...[
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nothing needs your attention right now.',
                      style: TextStyle(color: MizaniColors.muted),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

class _InvitationCard extends StatefulWidget {
  const _InvitationCard({required this.invitation});
  final Invitation invitation;

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    final session = context.read<SessionController>();
    try {
      final proposal = await session.repository.startInvitation(widget.invitation.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProposalFormScreen(proposalId: proposal.id)),
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = widget.invitation;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: _starting ? null : _start,
        title: Text(invitation.coverType.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'From ${invitation.partnerName} · open until ${formatDate(invitation.expiresAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: _starting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right, color: MizaniColors.muted),
      ),
    );
  }
}
