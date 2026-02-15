import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentIntent {
  final String id;
  final String orderId;
  final int amount;                 // in INR
  final String method;              // 'upi'
  final String status;              // 'pending' | 'success' | 'failed' | 'expired'
  final String upiDeepLink;         // upi://pay?... string
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentIntent({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.method,
    required this.status,
    required this.upiDeepLink,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'amount': amount,
    'method': method,
    'status': status,
    'upiDeepLink': upiDeepLink,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory PaymentIntent.fromSnap(DocumentSnapshot<Map<String, dynamic>> s) {
    final m = s.data()!;
    return PaymentIntent(
      id: s.id,
      orderId: m['orderId'],
      amount: (m['amount'] as num).toInt(),
      method: m['method'],
      status: m['status'],
      upiDeepLink: m['upiDeepLink'],
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      updatedAt: (m['updatedAt'] as Timestamp).toDate(),
    );
  }
}
