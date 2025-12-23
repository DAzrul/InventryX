import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stock_model.dart';

class StockService {
  final CollectionReference stockRef =
  FirebaseFirestore.instance.collection('stocks');

  Future<void> addStock(Stock stock) async {
    await stockRef.add(stock.toMap());
  }
}
