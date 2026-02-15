import 'package:cloud_firestore/cloud_firestore.dart';

/// ----------------------------
/// OrderItem Model
/// ----------------------------
class OrderItem {
  final String id;
  final String name;
  final int qty;
  final int price; // per unit

  OrderItem({
    required this.id,
    required this.name,
    required this.qty,
    required this.price,
  });

  int get lineTotal => qty * price;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'qty': qty,
    'price': price,
  };

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
    id: m['id'] as String,
    name: m['name'] as String,
    qty: (m['qty'] as num).toInt(),
    price: (m['price'] as num).toInt(),
  );
}

/// ----------------------------
/// OrderModel
/// ----------------------------
class OrderModel {
  final String id;
  final String vendorId;
  final String vendorName;
  final List<OrderItem> items;
  final int amount;
  final String status; // placed / preparing / out_for_delivery / delivered / cancelled
  final String paymentMethod; // upi / cash / netbank
  final String paymentStatus; // pending / success / failed
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  OrderModel({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.items,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'vendorId': vendorId,
    'vendorName': vendorName,
    'items': items.map((e) => e.toMap()).toList(),
    'amount': amount,
    'status': status,
    'paymentMethod': paymentMethod,
    'paymentStatus': paymentStatus,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  factory OrderModel.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final m = snap.data()!;
    return OrderModel(
      id: snap.id,
      vendorId: m['vendorId'] as String,
      vendorName: m['vendorName'] as String,
      items: (m['items'] as List)
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      amount: (m['amount'] as num).toInt(),
      status: m['status'] as String,
      paymentMethod: m['paymentMethod'] as String,
      paymentStatus: m['paymentStatus'] as String,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      updatedAt: (m['updatedAt'] as Timestamp).toDate(),
      notes: m['notes'] as String?,
    );
  }
}
