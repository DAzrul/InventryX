import 'package:cloud_firestore/cloud_firestore.dart';

class Stock {
  String? stockId; // document ID
  String productId;
  String productName;
  String size;
  int quantity;
  DateTime expiryDate;
  DateTime lastRestockedDate;
  String supplier;

  Stock({
    this.stockId,
    required this.productId,
    required this.productName,
    required this.size,
    required this.quantity,
    required this.expiryDate,
    required this.lastRestockedDate,
    required this.supplier,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'size': size,
      'quantity': quantity,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'lastRestockedDate': Timestamp.fromDate(lastRestockedDate),
      'supplier': supplier,
    };
  }
}
