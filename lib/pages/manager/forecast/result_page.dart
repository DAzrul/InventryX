import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// LOGIC & PAGES
import 'forecast_logic.dart';
import 'risk_scoring_page.dart';
import 'package:inventryx/pages/manager/manager_page.dart';
import 'package:inventryx/pages/manager/utils/manager_features_modal.dart';
import 'package:inventryx/pages/Profile/User_profile_page.dart';

// MODELS
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
  int _selectedIndex = 1;

  final Color primaryColor = const Color(0xFF233E99);
  final Color bgGrey = const Color(0xFFF4F7FF);

  @override
  void initState() {
    super.initState();
    _dataProcessingFuture = _processForecastData();
  }

  // --- CORE LOGIC: WEEKLY DATA AGGREGATION & CARTON CALCULATION ---
  Future<Map<String, dynamic>> _processForecastData() async {
    try {
      List<String> productIds = widget.selectedQuantities.keys.toList();
      if (productIds.isEmpty) return {"tableData": [], "uiResults": []};

      DateTime now = DateTime.now();
      DateTime todayStart = DateTime(now.year, now.month, now.day);

      List<DateTimeRange> weeks = List.generate(4, (index) {
        DateTime end = todayStart.subtract(Duration(days: index * 7));
        DateTime start = end.subtract(const Duration(days: 7));
        return DateTimeRange(start: start, end: end);
      }).reversed.toList();

      DateTime oldestDate = weeks.first.start;
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('productID', whereIn: productIds.take(10).toList())
          .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(oldestDate))
          .orderBy('saleDate', descending: false)
          .get();

      List<SalesModel> allSales = snapshot.docs.map((doc) {
        return SalesModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      List<Map<String, dynamic>> uiResults = [];
      List<Map<String, dynamic>> weeklyTableData = [];

      // --- INSIDE _processForecastData LOOP ---
      for (String productId in productIds) {
        ProductModel product;
        try {
          // Attempt to find product in list
          product = widget.allProducts.firstWhere((p) => p.id == productId);
        } catch (e) {
          debugPrint("❌ ERROR: Product ID $productId not found in allProducts list.");
          // FIX: Included all required fields for ProductModel
          product = ProductModel(
            id: productId,
            name: 'Unknown ($productId)',
            category: 'General',
            subCategory: 'General',
            imageUrl: '',
            price: 0.0,
            unitsPerCarton: 1,
          );
        }

        // Ensuring we pull the exact field name from your DB: unitsPerCarton
        int unitsPerCartonValue = product.unitsPerCarton ?? 1;
        if (unitsPerCartonValue <= 0) unitsPerCartonValue = 1;
        // --- ERROR FIX END ---

        final productSales = allSales.where((s) => s.productId == productId).toList();
        List<int> weeklyQuantities = [];

        for (int i = 0; i < weeks.length; i++) {
          final range = weeks[i];
          final salesInWeek = productSales.where((s) =>
          s.saleDate.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
              s.saleDate.isBefore(range.end)
          );

          int totalQty = salesInWeek.fold(0, (sum, item) => sum + item.quantitySold);
          weeklyQuantities.add(totalQty);

          weeklyTableData.add({
            'productName': product.name,
            'productId': productId,
            'weekLabel': "Week ${i + 1}",
            'range': "${DateFormat('dd/MM').format(range.start)} - ${DateFormat('dd/MM').format(range.end.subtract(const Duration(days: 1)))}",
            'qty': totalQty
          });
        }

        Map<String, dynamic> mathResult = ForecastLogic.generateForecast(weeklyQuantities);
        double predictedUnits = (mathResult['forecast'] as num).toDouble();

        // Final Formula
        double cartonsToOrder = predictedUnits / unitsPerCartonValue;

        ForecastModel forecast = ForecastModel(
          productId: productId,
          productName: product.name,
          forecastMethod: mathResult['method'],
          predictedDemand: predictedUnits,
          forecastDate: DateTime.now(),
        );

        await FirebaseFirestore.instance.collection('forecasts').doc(productId).set(
            forecast.toMap(),
            SetOptions(merge: true)
        );

        uiResults.add({
          "model": forecast,
          "trend": mathResult['trend'],
          "unitsPerCarton": unitsPerCartonValue,
          "cartonCount": cartonsToOrder.ceil(),
        });
      }

      return {"tableData": weeklyTableData, "uiResults": uiResults};
    } catch (e) {
      debugPrint("Final Processing Error: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          String currentUsername = "Manager";
          if (snapshot.hasData && snapshot.data!.exists) {
            var d = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = d['username'] ?? "Manager";
          }
          return Scaffold(
            backgroundColor: bgGrey,
            appBar: AppBar(
              title: const Text("Forecast Result", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black)),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            bottomNavigationBar: _buildFloatingNavBar(context, currentUsername, uid ?? ''),
            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildResultContent(),
                ProfilePage(username: currentUsername, userId: uid ?? ''),
              ],
            ),
          );
        }
    );
  }

  Widget _buildResultContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataProcessingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

        final tableData = snapshot.data!['tableData'] as List<Map<String, dynamic>>;
        final uiResults = snapshot.data!['uiResults'] as List<Map<String, dynamic>>;

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Weekly Sales Summary", Icons.calendar_view_week_rounded),
                    const SizedBox(height: 15),
                    _buildWeeklyTable(tableData),
                    const SizedBox(height: 30),
                    _buildSectionHeader("Forecast Analysis", Icons.analytics_rounded),
                    const SizedBox(height: 15),
                    ...uiResults.map((item) => _buildForecastCard(item)),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildActionFooter(uiResults),
          ],
        );
      },
    );
  }

  Widget _buildWeeklyTable(List<Map<String, dynamic>> data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.05)),
              children: const [
                Padding(padding: EdgeInsets.all(16), child: Text("Product", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Padding(padding: EdgeInsets.all(16), child: Text("Period", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Padding(padding: EdgeInsets.all(16), child: Text("Qty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
            ..._buildGroupedTableRows(data),
          ],
        ),
      ),
    );
  }

  List<TableRow> _buildGroupedTableRows(List<Map<String, dynamic>> data) {
    List<TableRow> rows = [];
    String lastId = "";
    for (int i = 0; i < data.length; i++) {
      var item = data[i];
      bool showName = item['productId'] != lastId;
      rows.add(TableRow(
        decoration: BoxDecoration(color: i % 2 == 0 ? Colors.white : bgGrey.withOpacity(0.3)),
        children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(showName ? item['productName'] : "", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['weekLabel'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Text(item['range'], style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: Text("${item['qty']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: primaryColor))),
        ],
      ));
      lastId = item['productId'];
    }
    return rows;
  }

  Widget _buildForecastCard(Map<String, dynamic> item) {
    final ForecastModel forecast = item['model'];
    final int cartonCount = item['cartonCount'];
    final int unitsPerCarton = item['unitsPerCarton'];
    final String trend = item['trend'];

    // Extract the method name (SMA or SES) from the model
    final String methodUsed = forecast.forecastMethod;

    bool isUp = trend.toLowerCase().contains("up") || trend.toLowerCase().contains("increase");

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(forecast.productName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: (isUp ? Colors.green : Colors.orange).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(trend, style: TextStyle(color: isUp ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          ),
          const Divider(height: 30),

          const Text("Forecast Demand", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$cartonCount", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryColor)),
              const Padding(padding: EdgeInsets.only(bottom: 5, left: 6), child: Text("Cartons", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
            ],
          ),

          const SizedBox(height: 15),

          // --- NEW: DISPLAY FORMULA METHOD ---
          Row(
            children: [
              Icon(Icons.functions_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                "Method Used: ",
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
              Text(
                methodUsed,
                style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Details section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgGrey, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailItem("Predicted Units", "${forecast.predictedDemand.round()}"),
                _buildDetailItem("Units/Carton", "$unitsPerCarton"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildActionFooter(List<Map<String, dynamic>> results) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: ElevatedButton(
        onPressed: () {
          List<ForecastModel> list = results.map((e) => e['model'] as ForecastModel).toList();
          Navigator.push(context, MaterialPageRoute(builder: (context) => RiskScoringPage(forecasts: list)));
        },
        style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
        ),
        child: const Text("Run Risk Scoring", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [Icon(icon, color: primaryColor, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]);
  }

  void _onItemTapped(BuildContext context, int index, String user, String uid) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => ManagerPage(loggedInUsername: user, userId: uid, username: '')), (r) => false);
    } else if (index == 1) {
      ManagerFeaturesModal.show(context, user, uid);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Widget _buildFloatingNavBar(BuildContext context, String user, String uid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      height: 65,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => _onItemTapped(context, i, user, uid),
        selectedItemColor: primaryColor, unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, elevation: 0, backgroundColor: Colors.transparent,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: "Features"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }
}