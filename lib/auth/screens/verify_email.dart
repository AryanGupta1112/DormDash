import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool loading = false;

  Future<void> _resendEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email resent. Check spam if needed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _checkVerified() async {
    if (loading) return;
    setState(() => loading = true);

    try {
      final auth = FirebaseAuth.instance;
      await auth.currentUser?.reload();
      await auth.currentUser?.getIdToken(true); // force token refresh
      final user = auth.currentUser;

      if (user != null && user.emailVerified) {
        // ensure Firestore profile (idempotent)
        try { await AuthService().ensureUserDoc(); } catch (_) {}

        if (!mounted) return;
        // If phone not yet linked, go link; else into app
        if (user.phoneNumber == null) {
          context.go('/otp');
        } else {
          context.go('/'); // AuthGate -> Shell
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still not verified. Please check your email.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    context.go('/'); // back to sign-in via AuthGate
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('We’ve sent a verification link to:', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text(
            'Open the link in your email to verify your account.\n'
                'Then tap the button below to continue.',
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: loading ? null : _checkVerified,
            icon: const Icon(Icons.verified),
            label: loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("I've Verified – Continue"),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _resendEmail,
            icon: const Icon(Icons.email_outlined),
            label: const Text('Resend Verification Email'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Cancel / Log Out'),
          ),
        ]),
      ),
    );
  }
}
