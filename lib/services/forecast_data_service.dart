/*import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_model.dart';
import '../models/forecast_model.dart';

class ForecastDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Fetch Sales History for selected products
  Future<List<SalesModel>> getSalesForProducts(List<String> productIds) async {
    if (productIds.isEmpty) return [];

    try {
      // NOTE: Firestore 'whereIn' is limited to 10 items per query.
      // We limit to 10 here to prevent crashes.
      QuerySnapshot snapshot = await _firestore
          .collection('sales')
          .where('ProductID', whereIn: productIds.take(10).toList())
          .orderBy('SaleDate', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        return SalesModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print("Error fetching sales data: $e");
      // Return empty list so app doesn't crash
      return [];
    }
  }

  // 2. Save calculated forecast to Firebase
  Future<void> saveForecast(ForecastModel forecast) async {
    try {
      await _firestore.collection('forecasts').add(forecast.toMap());
    } catch (e) {
      print("Error saving forecast: $e");
      throw e;
    }
  }
}*/