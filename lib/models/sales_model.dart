import 'package:cloud_firestore/cloud_firestore.dart';

class SalesModel {
  final String id;
  final String productId;
  final String productName;
  final int quantitySold;
  final DateTime saleDate;
  final double totalAmount;

  SalesModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.saleDate,
    required this.totalAmount,
  });

  factory SalesModel.fromMap(String id, Map<String, dynamic> map) {
    return SalesModel(
      id: id,
      // [PENTING] Tengok screenshot awak: 'productID' huruf besar ID
      productId: map['productID'] ?? '',
      // [PENTING] Nama produk dalam sales awak simpan sebagai 'snapshotName'
      productName: map['snapshotName'] ?? '',
      quantitySold: (map['quantitySold'] ?? 0).toInt(),
      saleDate: (map['saleDate'] as Timestamp).toDate(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
    );
  }
}