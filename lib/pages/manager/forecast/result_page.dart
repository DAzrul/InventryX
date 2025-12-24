/*import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Use 'package:inventryx/...' to find files easily anywhere in the project
import 'package:inventryx/models/sales_model.dart';
import 'package:inventryx/models/forecast_model.dart';
import 'forecast.dart';
import 'forecast_logic.dart';

class ResultPage extends StatefulWidget {
  final Map<String, int> selectedQuantities;
  final List<ProductModel> allProducts;

  const ResultPage({
    super.key,
    required this.selectedQuantities,
    required this.allProducts,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late Future<Map<String, dynamic>> _dataProcessingFuture;

  @override
  void initState() {
    super.initState();
    _dataProcessingFuture = _processForecastData();
  }

  // --- CORE LOGIC ---
  Future<Map<String, dynamic>> _processForecastData() async {
    try {
      List<String> productIds = widget.selectedQuantities.keys.toList();
      if (productIds.isEmpty) return {"tableData": [], "forecasts": []};

      // 1. FETCH ALL RELEVANT SALES
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('ProductID', whereIn: productIds.take(10).toList())
          .orderBy('SaleDate', descending: false)
          .get();

      List<SalesModel> allSales = snapshot.docs.map((doc) {
        return SalesModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      // 2. PREPARE DATA FOR UI
      List<SalesModel> tableDisplayList = [];
      List<forecast_model> forecastResults = [];

      for (String productId in productIds) {
        // A. Filter sales for this specific product
        final productSales = allSales.where((s) => s.productId == productId).toList();

        // B. Sort Ascending (Oldest -> Newest) for Forecast Math
        productSales.sort((a, b) => a.saleDate.compareTo(b.saleDate));

        // C. PREPARE TABLE DATA (Show Max 5 History)
        // We take the LAST 5 items (most recent) for the table
        int count = productSales.length;
        int startIndex = count > 5 ? count - 5 : 0;
        List<SalesModel> recentSales = productSales.sublist(startIndex);
        tableDisplayList.addAll(recentSales);

        // D. GENERATE FORECAST
        final List<int> quantityList = productSales.map((s) => s.quantitySold).toList();
        final String productName = _getProductName(productId);

        Map<String, dynamic> mathResult;
        if (quantityList.length < 5) {
          mathResult = {
            "forecast": 0.0,
            "method": "Insufficient Data",
            "trend": "Unknown"
          };
        } else {
          mathResult = ForecastLogic.generateForecast(quantityList);
        }

        ForecastModel forecast = ForecastModel(
          productId: productId,
          productName: productName,
          forecastMethod: mathResult['method'],
          predictedDemand: (mathResult['forecast'] as num).toDouble(),
          forecastDate: DateTime.now(),
        );

        forecastResults.add(forecast);

        // E. SAVE TO DATABASE
        await FirebaseFirestore.instance.collection('forecasts').add(forecast.toMap());
      }

      return {
        "tableData": tableDisplayList,
        "forecasts": forecastResults,
      };

    } catch (e) {
      debugPrint("Error in processing: $e");
      throw e;
    }
  }

  String _getProductName(String id) {
    final product = widget.allProducts.firstWhere(
          (p) => p.id == id,
      orElse: () => ProductModel(id: '', name: 'Unknown', category: '', subCategory: '', imageUrl: '', price: 0),
    );
    return product.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Forecast", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Features"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataProcessingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF233E99)));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final List<SalesModel> tableData = snapshot.data!['tableData'];
          final List<ForecastModel> forecasts = snapshot.data!['forecasts'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SECTION 1: SALES HISTORY TABLE ---
                const Text(
                  "Sales History",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF233E99),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Table(
                      border: TableBorder.symmetric(inside: const BorderSide(color: Colors.grey, width: 0.5)),
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.2),
                      },
                      children: [
                        const TableRow(
                          children: [
                            Padding(padding: EdgeInsets.all(12), child: Text("Product", style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(12), child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(12), child: Text("Qty Sold", style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                        // --- DYNAMIC ROWS ---
                        if (tableData.isEmpty)
                          const TableRow(children: [
                            Padding(padding: EdgeInsets.all(12), child: Text("-")),
                            Padding(padding: EdgeInsets.all(12), child: Text("-")),
                            Padding(padding: EdgeInsets.all(12), child: Text("-")),
                          ])
                        else
                          ..._buildGroupedTableRows(tableData),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- SECTION 2: FORECAST OUTPUT CARDS ---
                const Text(
                  "Forecast Output",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
                const SizedBox(height: 10),

                ...forecasts.map((forecast) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Product: ${forecast.productName}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text("Predicted Demand: ${forecast.predictedDemand.round()} units", style: const TextStyle(fontSize: 14, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text("Method Used: ${forecast.forecastMethod}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Risk Scoring Feature Coming Soon")));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF233E99),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Risk Scoring", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- HELPER TO GROUP ROWS VISUALLY ---
  // This ensures the Product Name only appears once per group
  List<TableRow> _buildGroupedTableRows(List<SalesModel> data) {
    List<TableRow> rows = [];
    String previousProductId = "";

    for (var sale in data) {
      String productName = _getProductName(sale.productId);

      // If same as previous, show empty string
      String displayProduct = (sale.productId == previousProductId) ? "" : productName;

      rows.add(TableRow(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(displayProduct, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Padding(padding: const EdgeInsets.all(12), child: Text(DateFormat('d/M/y').format(sale.saleDate), style: const TextStyle(fontSize: 13))),
          Padding(padding: const EdgeInsets.all(12), child: Text("${sale.quantitySold}", style: const TextStyle(fontSize: 13))),
        ],
      ));

      previousProductId = sale.productId;
    }
    return rows;
  }
}*/