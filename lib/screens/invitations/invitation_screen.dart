import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../models/models.dart';
import '../../theme/mizani_theme.dart';
import '../../widgets/api_loader.dart';
import '../auth/otp_screen.dart';
import '../cover/proposal_form_screen.dart';
import '../home/home_screen.dart';

/// What an invitation link opens. Shows who invited the client, then asks
/// for a code before any form data appears.
class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key, required this.token});

  final String token;

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  bool _sending = false;
  Object? _notFound;

  Future<Invitation> _load() async {
    try {
      return await context.read<SessionController>().repository.invitation(widget.token);
    } on ApiException catch (e) {
      if (e.isNotFound) {
        setState(() => _notFound = e);
      }
      rethrow;
    }
  }

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    final session = context.read<SessionController>();
    try {
      final challenge = await session.repository.requestInvitationOtp(widget.token);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (otpContext) => OtpScreen(
            maskedPhone: challenge.maskedPhone,
            channel: challenge.channel,
            resendAfter: challenge.resendAfter,
            onResend: () async {
              final next = await session.repository.requestInvitationOtp(widget.token);
              return next.resendAfter;
            },
            onVerify: (code) async {
              final proposal = await session.verifyInvitation(widget.token, code);
              if (!otpContext.mounted) return;
              final navigator = Navigator.of(otpContext);
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => ProposalFormScreen(proposalId: proposal.id),
                ),
              );
            },
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your invitation')),
      body: SafeArea(
        child: _notFound != null
            ? const MessageView(
                icon: Icons.error_outline,
                color: MizaniColors.bad,
                title: "We can't find this link",
                body: 'Check the link you were sent, or ask whoever invited you for a new one.',
              )
            : ApiLoader<Invitation>(
                load: _load,
                builder: (context, invitation, reload) {
                  if (invitation.isSubmitted) {
                    return MessageView(
                      icon: Icons.check_circle_outline,
                      color: MizaniColors.ok,
                      title: 'Already sent',
                      body: '${invitation.partnerName} has your application. Sign in to follow your quotes.',
                    );
                  }
                  if (!invitation.isOpen) {
                    return MessageView(
                      icon: Icons.schedule,
                      color: MizaniColors.warn,
                      title: 'This link is no longer active',
                      body: 'Ask ${invitation.partnerName} to send you a new one.',
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invitation.coverType.name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${invitation.partnerName} invited you to apply for this cover.',
                          style: const TextStyle(color: MizaniColors.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This link works until ${formatDate(invitation.expiresAt)}.',
                          style: const TextStyle(color: MizaniColors.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _sending ? null : _sendCode,
                            child: Text(_sending ? 'Sending…' : 'Send me a code'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
