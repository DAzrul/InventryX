import 'package:cloud_firestore/cloud_firestore.dart';

class SalesModel {
  final String salesId;
  final String productId; // This matches 'productID' in Firebase
  final int quantitySold;
  final DateTime saleDate;
  final String productName;

  SalesModel({
    required this.salesId,
    required this.productId,
    required this.quantitySold,
    required this.saleDate,
    required this.productName,
  });

  factory SalesModel.fromMap(String id, Map<String, dynamic> map) {
    return SalesModel(
      salesId: id,
      productId: map['productID'] ?? '', // Matches friend's code
      quantitySold: map['quantitySold'] ?? 0,
      saleDate: (map['saleDate'] as Timestamp).toDate(),
      productName: map['snapshotName'] ?? '',
    );
  }
}