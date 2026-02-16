import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  final phoneCtrl = TextEditingController();
  final regCtrl   = TextEditingController();
  final _formKey  = GlobalKey<FormState>();

  bool loading = false;
  bool _navLocked = false; // debounce nav actions
  bool _obscure = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    phoneCtrl.dispose();
    regCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);
    try {
      await AuthService().signUp(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        regNo: regCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Verification email sent.')),
      );
      context.go('/'); // AuthGate will show VerifyEmailScreen until verified
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _safePop() {
    if (_navLocked || loading) return;
    _navLocked = true;
    if (context.canPop()) context.pop();
    Future.delayed(const Duration(milliseconds: 300), () => _navLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !loading, // block system back while loading
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Account'),
          leading: BackButton(onPressed: loading ? null : _safePop),
        ),
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
                  decoration: const InputDecoration(labelText: 'College Email'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter email' : null,
                ),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Phone (+E.164)'),
                ),
                TextFormField(
                  controller: regCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Registration Number'),
                ),
                TextFormField(
                  controller: passCtrl,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) =>
                  (v == null || v.length < 6) ? 'Use at least 6 characters' : null,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
