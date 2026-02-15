import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment.dart';

class PaymentService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('payments');

  String buildUpiDeepLink({
    required String upiId,
    required String payeeName,
    required int amount,
    String note = 'Campus Order',
  }) {
    // Amount as string, avoid decimals for simplicity.
    return 'upi://pay?pa=$upiId&pn=$payeeName&am=$amount&cu=INR&tn=${Uri.encodeComponent(note)}';
  }

  Future<String> createIntent({
    required String orderId,
    required int amount,
    required String upiId,
    required String payeeName,
  }) async {
    final link = buildUpiDeepLink(
      upiId: upiId, payeeName: payeeName, amount: amount,
    );
    final doc = await _col.add({
      'orderId': orderId,
      'amount': amount,
      'method': 'upi',
      'status': 'pending',
      'upiDeepLink': link,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<PaymentIntent?> watch(String paymentId) {
    return _col.doc(paymentId).snapshots().map((s) => s.exists ? PaymentIntent.fromSnap(s) : null);
  }

  Future<void> markSuccess(String paymentId) =>
      _col.doc(paymentId).update({'status': 'success', 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> markFailed(String paymentId) =>
      _col.doc(paymentId).update({'status': 'failed', 'updatedAt': FieldValue.serverTimestamp()});
}
