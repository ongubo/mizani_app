import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../theme/mizani_theme.dart';
import '../../widgets/otp_input.dart';

/// Enter a 6-digit code, for sign-in or an invitation link. [onVerify] does
/// the work and the navigation, and throws [ApiException] if the code is wrong.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.maskedPhone,
    required this.channel,
    required this.resendAfter,
    required this.onVerify,
    required this.onResend,
  });

  final String maskedPhone;
  final String channel;
  final int resendAfter;
  final Future<void> Function(String code) onVerify;

  /// Sends a new code and returns the seconds until another may be sent.
  final Future<int> Function() onResend;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpKey = GlobalKey<OtpInputState>();
  Timer? _timer;
  String? _error;
  bool _verifying = false;
  int _resendIn = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.resendAfter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    _resendIn = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendIn <= 1) {
        timer.cancel();
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _submit(String code) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await widget.onVerify(code);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.message;
      });
      _otpKey.currentState?.clear();
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      final seconds = await widget.onResend();
      if (mounted) setState(() => _startCountdown(seconds));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.channel == 'sms'
        ? 'by SMS to ${widget.maskedPhone}'
        : 'to the email on the account for ${widget.maskedPhone}';

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: MizaniColors.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.lock_outline, color: MizaniColors.brand),
            ),
            const SizedBox(height: 18),
            const Text(
              "Verify it's you",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the 6-digit code sent $destination.',
              style: const TextStyle(color: MizaniColors.muted),
            ),
            const SizedBox(height: 20),
            OtpInput(key: _otpKey, onCompleted: _submit, errorText: _error),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _resendIn > 0
                      ? 'Resend in 0:${_resendIn.toString().padLeft(2, '0')}'
                      : "Didn't receive it?",
                  style: const TextStyle(fontSize: 13, color: MizaniColors.muted),
                ),
                TextButton(
                  onPressed: _resendIn == 0 ? _resend : null,
                  child: const Text('Resend code'),
                ),
              ],
            ),
            if (_verifying) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
