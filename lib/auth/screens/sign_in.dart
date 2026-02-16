import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  final _formKey  = GlobalKey<FormState>();
  bool loading = false;
  bool _navLocked = false;
  bool _obscure = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  String _mapError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email': return 'That email looks invalid.';
        case 'user-not-found':
        case 'wrong-password':
        case 'INVALID_LOGIN_CREDENTIALS':
          return 'Email or password is incorrect.';
        case 'user-disabled': return 'This account has been disabled.';
      }
    }
    return e.toString();
  }

  Future<void> _doSignIn() async {
    if (loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);
    try {
      await AuthService().signIn(emailCtrl.text.trim(), passCtrl.text.trim());

      // if user is already verified, ensure profile doc (idempotent) and go in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        try { await AuthService().ensureUserDoc(); } catch (_) {}
      }

      if (!mounted) return;
      context.go('/'); // AuthGate → Shell or VerifyEmail
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mapError(e))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _goTo(String path) async {
    if (_navLocked) return;
    _navLocked = true;
    await context.push(path);
    _navLocked = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter email' : null,
              ),
              TextFormField(
                controller: passCtrl,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _doSignIn(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                obscureText: _obscure,
                validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter password' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: loading ? null : _doSignIn,
                child: loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Sign In'),
              ),
              TextButton(
                onPressed: () => _goTo('/signup'),
                child: const Text('New user? Create account'),
              ),
              TextButton(
                onPressed: () => _goTo('/otp'),
                child: const Text('Sign in with phone number'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
