import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../models/models.dart';
import '../../theme/mizani_theme.dart';
import '../home/home_screen.dart';
import '../invitations/invitation_screen.dart';
import 'otp_screen.dart';

/// Sign in with a phone number, national ID or policy number, then a code.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = _identifier.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Enter your phone number, ID or policy number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final session = context.read<SessionController>();
    try {
      final challenge = await session.requestCode(identifier);
      if (!mounted) return;
      _openOtp(identifier, challenge);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openOtp(String identifier, OtpChallenge first) {
    final session = context.read<SessionController>();
    var challenge = first;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (otpContext) => OtpScreen(
          maskedPhone: first.maskedPhone,
          channel: first.channel,
          resendAfter: first.resendAfter,
          onResend: () async {
            challenge = await session.requestCode(identifier);
            return challenge.resendAfter;
          },
          onVerify: (code) async {
            await session.verifyCode(challenge.challengeId!, code);
            if (!otpContext.mounted) return;
            Navigator.of(otpContext).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  Future<void> _openInvitation() async {
    final token = await showDialog<String>(
      context: context,
      builder: (_) => const _InvitationLinkDialog(),
    );
    if (token == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvitationScreen(token: token)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/branding/login_background.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Mizani',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your cover, in balance',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: MizaniColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 24,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        children: [
                          const Text(
                            'Welcome',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Enter your phone number, ID or policy number and we'll send you a code.",
                            style: TextStyle(
                              color: MizaniColors.muted,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _identifier,
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Phone, ID or policy number',
                              prefixIcon: const Icon(Icons.person_outline),
                              errorText: _error,
                              errorMaxLines: 3,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: Text(_loading ? 'Sending…' : 'Send code'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _openInvitation,
                            child: const Text('I have an invitation link'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationLinkDialog extends StatefulWidget {
  const _InvitationLinkDialog();

  @override
  State<_InvitationLinkDialog> createState() => _InvitationLinkDialogState();
}

class _InvitationLinkDialogState extends State<_InvitationLinkDialog> {
  final _link = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _open() {
    final token = invitationTokenFrom(_link.text);
    if (token == null) {
      setState(() => _error = "That doesn't look like an invitation link.");
      return;
    }
    Navigator.of(context).pop(token);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Open your invitation'),
      content: TextField(
        controller: _link,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Paste the link you received',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _open, child: const Text('Open')),
      ],
    );
  }
}

/// The token from a pasted `https://.../i/{token}` link, or a bare token.
String? invitationTokenFrom(String input) {
  final text = input.trim();
  final fromLink = RegExp(r'/i/([A-Za-z0-9]+)').firstMatch(text);
  if (fromLink != null) {
    return fromLink.group(1);
  }
  return RegExp(r'^[A-Za-z0-9]+$').hasMatch(text) ? text : null;
}
