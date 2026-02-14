import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // --- Sign Up (email-first) ---
  Future<void> signUp({
    required String email,
    required String password,
    required String phone,  // collected but only trusted after OTP
    required String regNo,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email BEFORE any Firestore writes
      await cred.user!.sendEmailVerification();

      // Temporarily stash (phone|regNo) so we can create the doc after verification
      await cred.user!.updateDisplayName('$phone|$regNo');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('This email is already registered. Please sign in instead.');
      }
      throw Exception(e.message ?? e.code);
    }
  }

  // --- Ensure Firestore user doc (call after email is verified) ---
  Future<void> ensureUserDoc() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final parts = user.displayName?.split('|');
    final phoneDraft = parts != null && parts.isNotEmpty ? parts[0] : '';
    final regNo      = parts != null && parts.length > 1 ? parts[1] : '';

    final docRef = _db.collection('users').doc(user.uid);
    final snap = await docRef.get();

    if (!snap.exists) {
      await docRef.set({
        'email'         : user.email,
        'regNo'         : regNo,
        'phoneDraft'    : phoneDraft.isNotEmpty ? phoneDraft : null,
        'phone'         : user.phoneNumber,
        'phoneVerified' : user.phoneNumber != null,
        'createdAt'     : FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.set({
        'email': user.email,
        if (regNo.isNotEmpty) 'regNo': regNo,
      }, SetOptions(merge: true));
    }
  }

  // --- Sign In ---
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // --- Sign Out ---
  Future<void> signOut() async => _auth.signOut();

  /// --- Send Phone OTP ---
  Future<void> sendOtp(
      String phone,
      void Function(String, int?) onCodeSent, {
        int? forceResendToken,
        void Function()? onAutoVerified,
        void Function(String message)? onFailed,
      }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: forceResendToken,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final user = _auth.currentUser;
          if (user != null) {
            try {
              await user.linkWithCredential(credential);
            } catch (e) {
              if (e is FirebaseAuthException && e.code == 'provider-already-linked') {
                // already linked; ignore
              } else {
                throw e;
              }
            }
            await user.reload(); // ensure phoneNumber is updated
            final refreshed = _auth.currentUser;

            await _db.collection('users').doc(user.uid).set({
              'phone'         : refreshed?.phoneNumber,
              'phoneVerified' : true,
              'phoneDraft'    : null,
            }, SetOptions(merge: true));
          } else {
            // No session — sign in with phone and create doc
            final res = await _auth.signInWithCredential(credential);
            await _db.collection('users').doc(res.user!.uid).set({
              'email'         : res.user!.email,
              'phone'         : res.user!.phoneNumber,
              'phoneVerified' : true,
              'createdAt'     : FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
          onAutoVerified?.call();
        } on FirebaseAuthException catch (e) {
          onFailed?.call(e.message ?? e.code);
        } catch (e) {
          onFailed?.call(e.toString());
        }
      },

      verificationFailed: (FirebaseAuthException e) {
        onFailed?.call(e.message ?? e.code);
      },

      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId, resendToken);
      },

      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // --- Verify Phone OTP (manual entry) ---
  Future<void> verifyOtp(String verificationId, String smsCode) async {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.linkWithCredential(cred);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'provider-already-linked') {
          throw Exception(e.message ?? e.code);
        }
      }

      await user.reload();
      final refreshed = _auth.currentUser;

      await _db.collection('users').doc(user.uid).set({
        'phone'         : refreshed?.phoneNumber,
        'phoneVerified' : true,
        'phoneDraft'    : null,
      }, SetOptions(merge: true));
      return;
    }

    // Edge: no session — sign-in with phone & ensure doc
    final res = await _auth.signInWithCredential(cred);
    await _db.collection('users').doc(res.user!.uid).set({
      'email'         : res.user!.email,
      'phone'         : res.user!.phoneNumber,
      'phoneVerified' : true,
      'createdAt'     : FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  User? get currentUser => _auth.currentUser;
}
