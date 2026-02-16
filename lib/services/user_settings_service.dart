import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_settings.dart';

/// ----------------------------
/// Reads/writes the user.settings map in Firestore
/// ----------------------------
class UserSettingsService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(_uid);

  Future<UserSettings> getSettings() async {
    final snap = await _userDoc.get();
    return UserSettings.fromMap(snap.data()?['settings'] as Map<String, dynamic>?);
  }

  Future<void> updateSettings(UserSettings s) async {
    await _userDoc.set({
      'settings': s.toMap(),
    }, SetOptions(merge: true));
  }
}
