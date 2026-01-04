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
  int _selectedIndex = 1; // Tab Features

  final Color primaryColor = const Color(0xFF233E99);
  final Color bgGrey = const Color(0xFFF4F7FF);

  @override
  void initState() {
    super.initState();
    _dataProcessingFuture = _processForecastData();
  }

  // --- NAVIGATION ---
  void _onItemTapped(BuildContext context, int index, String currentUsername, String uid) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ManagerPage(
            loggedInUsername: currentUsername,
            userId: uid,
            username: '',
          ),
        ),
            (Route<dynamic> route) => false,
      );
    } else if (index == 1) {
      ManagerFeaturesModal.show(context, currentUsername, uid);
    } else if (index == 2) {
      setState(() => _selectedIndex = index);
    }
  }

  // --- CORE LOGIC ---
  Future<Map<String, dynamic>> _processForecastData() async {
    try {
      List<String> productIds = widget.selectedQuantities.keys.toList();
      if (productIds.isEmpty) return {"tableData": [], "uiResults": []};

      // 1. FETCH SALES HISTORY
      // [FIX] Guna 'productID' (Huruf Besar ID) ikut screenshot Firestore awak
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('productID', whereIn: productIds.take(10).toList())
          .orderBy('saleDate', descending: false)
          .get();

      // Debugging: Check berapa data jumpa
      debugPrint("Jumpa ${snapshot.docs.length} rekod jualan.");

      List<SalesModel> allSales = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return SalesModel.fromMap(doc.id, data);
      }).toList();

      List<SalesModel> tableDisplayList = [];
      List<Map<String, dynamic>> uiResults = [];

      for (String productId in productIds) {
        // Filter sales untuk produk ni
        final productSales = allSales.where((s) => s.productId == productId).toList();
        productSales.sort((a, b) => a.saleDate.compareTo(b.saleDate));

        // Ambil last 5 transaction untuk table display
        int count = productSales.length;
        int startIndex = count > 5 ? count - 5 : 0;
        tableDisplayList.addAll(productSales.sublist(startIndex));

        // Generate Forecast (Math)
        final List<int> quantityList = productSales.map((s) => s.quantitySold).toList();
        final String productName = _getProductName(productId);

        Map<String, dynamic> mathResult = ForecastLogic.generateForecast(quantityList);

        ForecastModel forecast = ForecastModel(
          productId: productId,
          productName: productName,
          forecastMethod: mathResult['method'],
          predictedDemand: (mathResult['forecast'] as num).toDouble(),
          forecastDate: DateTime.now(),
        );

        // Simpan result forecast ke database
        await FirebaseFirestore.instance.collection('forecasts').doc(productId).set(
            forecast.toMap(),
            SetOptions(merge: true)
        );

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
      return 'Unknown Product';
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
          final safeUid = uid ?? '';

          return Scaffold(
            backgroundColor: bgGrey,
            appBar: AppBar(
              title: const Text(
                "Forecast Result",
                style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w800, fontSize: 18),
              ),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            bottomNavigationBar: _buildFloatingNavBar(context, currentUsername, safeUid),

            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildResultContent(),
                ProfilePage(username: currentUsername, userId: safeUid),
              ],
            ),
          );
        }
    );
  }

  // --- NAVBAR ---
  Widget _buildFloatingNavBar(BuildContext context, String currentUsername, String uid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => _onItemTapped(context, index, currentUsername, uid),
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          items: [
            _navItem(Icons.home_outlined, Icons.home_rounded, "Home"),
            _navItem(Icons.grid_view_outlined, Icons.grid_view_rounded, "Features"),
            _navItem(Icons.person_outline_rounded, Icons.person_rounded, "Profile"),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData inactiveIcon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(
      icon: Icon(inactiveIcon, size: 22),
      activeIcon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(activeIcon, size: 22, color: primaryColor),
      ),
      label: label,
    );
  }

  // --- CONTENT ---
  Widget _buildResultContent() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataProcessingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final List<SalesModel> tableData = snapshot.data!['tableData'] as List<SalesModel>;
        final List<Map<String, dynamic>> uiResults = snapshot.data!['uiResults'] as List<Map<String, dynamic>>;

        if (uiResults.isEmpty) {
          return const Center(child: Text("No sales data found for selected items."));
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Sales History", Icons.history_rounded),
                    const SizedBox(height: 15),

                    // SALES HISTORY TABLE
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1.5),
                            2: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.05)),
                              children: const [
                                Padding(padding: EdgeInsets.all(16), child: Text("Product", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                Padding(padding: EdgeInsets.all(16), child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                Padding(padding: EdgeInsets.all(16), child: Text("Qty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              ],
                            ),
                            // Panggil function row generator
                            ..._buildGroupedTableRows(tableData),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    _buildSectionHeader("Forecast Analysis", Icons.analytics_rounded),
                    const SizedBox(height: 15),

                    // FORECAST CARDS
                    ...uiResults.map((item) {
                      return _buildForecastCard(item['model'], item['trend']);
                    }),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // BUTTON RISK SCORING
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.08), offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                height: 55,
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
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: primaryColor.withOpacity(0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Run Risk Scoring", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E))),
      ],
    );
  }

  Widget _buildForecastCard(ForecastModel forecast, String trend) {
    bool isUptrend = trend.toLowerCase().contains("up") || trend.toLowerCase().contains("increase");
    Color trendColor = isUptrend ? Colors.green : Colors.orange;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(forecast.productName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: trendColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(isUptrend ? Icons.trending_up : Icons.trending_down, size: 14, color: trendColor),
                    const SizedBox(width: 4),
                    Text(trend, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: trendColor)),
                  ],
                ),
              )
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          Row(
            children: [
              _buildStatColumn("Predicted", "${forecast.predictedDemand.round()} units", primaryColor),
              const Spacer(),
              _buildStatColumn("Method", forecast.forecastMethod, Colors.grey.shade600),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
      ],
    );
  }

  // --- FIX TABLE ROW GENERATOR ---
  List<TableRow> _buildGroupedTableRows(List<SalesModel> data) {
    List<TableRow> rows = [];
    String previousProductId = "";

    // 1. Handle Empty Data dengan kemas
    if (data.isEmpty) {
      return [
        const TableRow(children: [
          Padding(padding: EdgeInsets.all(16), child: Text("No Data", style: TextStyle(fontSize: 12, color: Colors.grey))),
          Padding(padding: EdgeInsets.all(16), child: Text("-")),
          Padding(padding: EdgeInsets.all(16), child: Text("-")),
        ])
      ];
    }

    for (var i = 0; i < data.length; i++) {
      var sale = data[i];
      // 2. Logic nama produk (Kalau nama kosong, ambil dari list produk)
      String productName = sale.productName.isNotEmpty ? sale.productName : _getProductName(sale.productId);

      // 3. Grouping: Kalau produk sama dengan row atas, jangan ulang nama (biar kosong)
      String displayProduct = (sale.productId == previousProductId) ? "" : productName;

      // 4. Zebra Striping (Warna selang-seli)
      Color rowColor = (i % 2 == 0) ? Colors.white : bgGrey.withOpacity(0.5);

      rows.add(TableRow(
        decoration: BoxDecoration(color: rowColor),
        children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(displayProduct, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87))
          ),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(DateFormat('dd MMM yy').format(sale.saleDate), style: const TextStyle(fontSize: 12, color: Colors.grey))
          ),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text("${sale.quantitySold}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor))
          ),
        ],
      ));
      previousProductId = sale.productId;
    }
    return rows;
  }
}