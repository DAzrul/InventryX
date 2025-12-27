import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// 1. IMPORT LOGIC
import 'forecast_logic.dart';
import 'risk_scoring_page.dart';

// 2. IMPORT SHARED MODELS
import 'package:inventryx/models/forecast_model.dart';
import 'package:inventryx/models/product_model.dart';
import 'package:inventryx/models/sales_model.dart';

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
      if (productIds.isEmpty) return {"tableData": [], "uiResults": []};

      // 1. FETCH SALES HISTORY
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('productID', whereIn: productIds.take(10).toList())
          .orderBy('saleDate', descending: false)
          .get();

      // Convert Firebase data to SalesModel
      List<SalesModel> allSales = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return SalesModel.fromMap(doc.id, data);
      }).toList();

      // 2. PREPARE DATA FOR UI
      List<SalesModel> tableDisplayList = [];
      List<Map<String, dynamic>> uiResults = [];

      for (String productId in productIds) {
        // A. Filter & Sort Sales
        final productSales = allSales.where((s) => s.productId == productId).toList();
        productSales.sort((a, b) => a.saleDate.compareTo(b.saleDate));

        // B. Add LAST 5 transactions to Table
        int count = productSales.length;
        int startIndex = count > 5 ? count - 5 : 0;
        tableDisplayList.addAll(productSales.sublist(startIndex));

        // C. GENERATE FORECAST (Math)
        final List<int> quantityList = productSales.map((s) => s.quantitySold).toList();
        final String productName = _getProductName(productId);

        Map<String, dynamic> mathResult = ForecastLogic.generateForecast(quantityList);

        // D. CREATE FORECAST OBJECT
        ForecastModel forecast = ForecastModel(
          productId: productId,
          productName: productName,
          forecastMethod: mathResult['method'],
          predictedDemand: (mathResult['forecast'] as num).toDouble(),
          forecastDate: DateTime.now(),
        );

        // E. SAVE RESULT TO DATABASE
        await FirebaseFirestore.instance.collection('forecasts').doc(productId).set(
            forecast.toMap(),
            SetOptions(merge: true)
        );

        // F. PREPARE UI CARD
        uiResults.add({
          "model": forecast,
          "trend": mathResult['trend']
        });
      }

      return {
        "tableData": tableDisplayList,
        "uiResults": uiResults,
      };

    } catch (e) {
      debugPrint("Error in processing: $e");
      throw e;
    }
  }

  String _getProductName(String id) {
    try {
      final product = widget.allProducts.firstWhere((p) => p.id == id);
      return product.name;
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Forecast Results", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
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

          final List<SalesModel> tableData = snapshot.data!['tableData'] as List<SalesModel>;
          final List<Map<String, dynamic>> uiResults = snapshot.data!['uiResults'] as List<Map<String, dynamic>>;

          if (uiResults.isEmpty) {
            return const Center(child: Text("No sales data found for selected items."));
          }

          // === LAYOUT CHANGE: Use Column + Expanded to force button to bottom ===
          return Column(
            children: [
              // 1. SCROLLABLE AREA (Takes up all available space)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Sales History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      const SizedBox(height: 10),

                      // Table
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF233E99),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1.5),
                              2: FlexColumnWidth(1),
                            },
                            border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade300)),
                            children: [
                              const TableRow(
                                children: [
                                  Padding(padding: EdgeInsets.all(12), child: Text("Product", style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(12), child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(12), child: Text("Qty Sold", style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                              ..._buildGroupedTableRows(tableData),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      const Text("Forecast Output", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      const SizedBox(height: 10),

                      // Forecast Cards
                      ...uiResults.map((item) {
                        return _buildForecastCard(item['model'], item['trend']);
                      }),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // 2. FIXED BOTTOM AREA (This sits right above the footer/navbar)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  // Optional: Add a subtle shadow so it looks separated from the list
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      final List<Map<String, dynamic>> uiResults = snapshot.data!['uiResults'] as List<Map<String, dynamic>>;
                      List<ForecastModel> forecastsToSend = uiResults.map((item) => item['model'] as ForecastModel).toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RiskScoringPage(forecasts: forecastsToSend),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF233E99),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Risk Scoring", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForecastCard(ForecastModel forecast, String trend) {
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
          Text("Trend: $trend", style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  List<TableRow> _buildGroupedTableRows(List<SalesModel> data) {
    List<TableRow> rows = [];
    String previousProductId = "";

    if (data.isEmpty) {
      return [const TableRow(children: [
        Padding(padding: EdgeInsets.all(12), child: Text("-")),
        Padding(padding: EdgeInsets.all(12), child: Text("-")),
        Padding(padding: EdgeInsets.all(12), child: Text("-")),
      ])];
    }

    for (var sale in data) {
      String productName = sale.productName.isNotEmpty ? sale.productName : _getProductName(sale.productId);
      String displayProduct = (sale.productId == previousProductId) ? "" : productName;

      rows.add(TableRow(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(displayProduct, style: const TextStyle(fontSize: 13))),
          Padding(padding: const EdgeInsets.all(12), child: Text(DateFormat('d/M/yyyy').format(sale.saleDate), style: const TextStyle(fontSize: 13))),
          Padding(padding: const EdgeInsets.all(12), child: Text("${sale.quantitySold}", style: const TextStyle(fontSize: 13))),
        ],
      ));
      previousProductId = sale.productId;
    }
    return rows;
  }
}