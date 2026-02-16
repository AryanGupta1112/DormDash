import 'dart:async';
import 'package:flutter/material.dart';
import '../auth_service.dart';

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key});
  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final phoneCtrl = TextEditingController(); // e.g. +91XXXXXXXXXX
  final otpCtrl   = TextEditingController();

  String? _verificationId;
  int? _forceResendToken;
  bool _sending = false;
  bool _verifying = false;
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _timer?.cancel();
    phoneCtrl.dispose();
    otpCtrl.dispose();
    super.dispose();
  }

  void _startCountdown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    final phone = phoneCtrl.text.trim();
    if (!phone.startsWith('+') || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone in E.164 format, e.g. +91XXXXXXXXXX')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await AuthService().sendOtp(
        phone,
            (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _forceResendToken = resendToken;
            _sending = false;
          });
          _startCountdown(60);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent!')));
        },
        forceResendToken: isResend ? _forceResendToken : null,
        onAutoVerified: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phone verified automatically!')),
          );
          Navigator.of(context).pop(); // AuthGate refresh; Account will reflect verified phone
        },
        onFailed: (msg) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          setState(() => _sending = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please send OTP first')));
      return;
    }
    final code = otpCtrl.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the 6-digit OTP')));
      return;
    }

    setState(() => _verifying = true);
    try {
      await AuthService().verifyOtp(_verificationId!, code);
      if (!mounted) return;
      Navigator.of(context).pop(); // AuthGate refresh; Account reflects verified phone
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0 && _verificationId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login / Link')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone Number (E.164)',
                hintText: '+91XXXXXXXXXX',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _sending ? null : () => _sendOtp(isResend: false),
                  child: _sending
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send OTP'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: canResend ? () => _sendOtp(isResend: true) : null,
                  child: Text(canResend ? 'Resend' : 'Resend in $_secondsLeft s'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_verificationId != null) ...[
              TextField(
                controller: otpCtrl,
                maxLength: 6,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verifyOtp(),
                decoration: const InputDecoration(labelText: 'Enter OTP'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _verifying ? null : _verifyOtp,
                child: _verifying
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify & Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
