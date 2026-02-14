import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/sign_in.dart';
import 'screens/verify_email.dart';

class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // userChanges() fires when emailVerified flips after reload()
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data;
        if (user == null) {
          return const SignInScreen(); // not logged in
        }

        // Require verified email before entering the app
        if (!(user.emailVerified)) {
          return const VerifyEmailScreen();
        }

        return child; // logged in + verified -> show the app
      },
    );
  }
}
