import 'package:cloud_firestore/cloud_firestore.dart';

class ForecastModel {
  final String? id; // Firebase Document ID (Auto-generated)
  final String productId; // LINKS TO: The long ID "15NLd..." from your screenshot
  final String productName; // Optional: Store name too so you don't have to look it up every time
  final String forecastMethod; // e.g., "SMA", "SES"
  final double predictedDemand; // e.g., 150.0
  final DateTime forecastDate;

  ForecastModel({
    this.id,
    required this.productId,
    required this.productName,
    required this.forecastMethod,
    required this.predictedDemand,
    required this.forecastDate,
  });

  // Convert to Map for saving to Firebase
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'forecastMethod': forecastMethod,
      'predictedDemand': predictedDemand,
      'forecastDate': Timestamp.fromDate(forecastDate), // Firebase uses Timestamp
    };
  }

  // Create Object from Firebase Data
  factory ForecastModel.fromMap(String docId, Map<String, dynamic> map) {
    return ForecastModel(
      id: docId,
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      forecastMethod: map['forecastMethod'] ?? 'Unknown',
      predictedDemand: (map['predictedDemand'] ?? 0).toDouble(),
      forecastDate: (map['forecastDate'] as Timestamp).toDate(),
    );
  }
}