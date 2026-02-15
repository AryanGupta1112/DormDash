import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';

/// ----------------------------
/// Handles user-level order creation & updates
/// ----------------------------
class OrderService {
  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _db.collection('users').doc(_uid).collection('orders');

  /// Create a new order document under users/{uid}/orders/{orderId}
  Future<String> createOrder({
    required String vendorId,
    required String vendorName,
    required List<OrderItem> items,
    required int amount,
    required String paymentMethod, // upi | cash | netbank
    String paymentStatus = 'pending',
    String notes = '',
  }) async {
    final doc = await _ordersCol.add({
      'vendorId': vendorId,
      'vendorName': vendorName,
      'items': items.map((e) => e.toMap()).toList(),
      'amount': amount,
      'status': 'placed',
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (notes.isNotEmpty) 'notes': notes,
    });
    return doc.id;
  }

  /// Stream all user orders (latest first)
  Stream<List<OrderModel>> streamMyOrders() {
    return _ordersCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map(OrderModel.fromSnap).toList());
  }

  /// Mark payment success manually (for UPI confirmation or COD verified)
  Future<void> markPaymentSuccess(String orderId) {
    return _ordersCol.doc(orderId).update({
      'paymentStatus': 'success',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

// Future hooks for driver/vendor role updates will live here later
}
