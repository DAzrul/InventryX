import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as ex;
import 'package:firebase_auth/firebase_auth.dart';

// [PENTING] Import navigation admin
import '../admin/admin_page.dart';
import '../admin/utils/features_modal.dart'; // Modal Admin
import '../Profile/User_profile_page.dart';

class ReportPage extends StatefulWidget {
  final String? loggedInUsername;
  final String? userId;

  const ReportPage({super.key, this.loggedInUsername, this.userId});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _selectedIndex = 1;
  final Color primaryBlue = const Color(0xFF233E99);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- LOGIC NAVIGATION ---
  void _onItemTapped(int index) {
    if (index == 0) {
      final user = FirebaseAuth.instance.currentUser;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => AdminPage(
            username: widget.loggedInUsername ?? "Admin",
            userId: user?.uid ?? '', loggedInUsername: '',
          ),
        ),
            (Route<dynamic> route) => false,
      );
    } else if (index == 1) {
      FeaturesModal.show(context, widget.loggedInUsername ?? "Admin");
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentUsername = widget.loggedInUsername ?? "Admin";
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            var d = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = d['username'] ?? currentUsername;
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFF),
            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildReportUI(context),
                ProfilePage(username: currentUsername, userId: uid ?? ''),
              ],
            ),
            bottomNavigationBar: _buildFloatingNavBar(),
          );
        });
  }

  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: primaryBlue,
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
        decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(activeIcon, size: 22, color: primaryBlue),
      ),
      label: label,
    );
  }

  Widget _buildReportUI(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("Reports & Analytics",
            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E), fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.file_download_outlined, color: primaryBlue, size: 22),
              ),
              onPressed: () => _showExportOptions(context),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 4,
          indicatorColor: primaryBlue,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: const [Tab(text: "Inventory"), Tab(text: "Forecast"), Tab(text: "Risk")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InventoryReportTab(db: _db),
          _ForecastReportTab(db: _db),
          _RiskReportTab(db: _db),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            const Text("Export Options", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
            const SizedBox(height: 30),
            _exportTile(Icons.picture_as_pdf_rounded, "Download PDF Report", Colors.red, () { Navigator.pop(ctx); }),
            const SizedBox(height: 12),
            _exportTile(Icons.table_chart_rounded, "Download Excel Sheet", Colors.green, () { Navigator.pop(ctx); }),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _exportTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 15),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}

// ======================== TAB 1: INVENTORY (KEKAL) ========================
class _InventoryReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _InventoryReportTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        double totalValue = 0;
        Map<String, double> catData = {};
        final docs = snapshot.data!.docs;

        for (var doc in docs) {
          double p = double.tryParse(doc['price']?.toString() ?? '0') ?? 0;
          int s = int.tryParse(doc['currentStock']?.toString() ?? '0') ?? 0;
          totalValue += (p * s);
          catData[doc['category'] ?? 'Others'] = (catData[doc['category']] ?? 0) + s.toDouble();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildPremiumStatCard("Estimated Asset Value", "RM ${totalValue.toStringAsFixed(2)}", Icons.account_balance_wallet_outlined, const Color(0xFF233E99)),
            const SizedBox(height: 35),
            const Text("Category Distribution", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 15),
            _buildCleanBarChart(catData),
            const SizedBox(height: 35),
            const Text("Critical Stock Alerts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.redAccent)),
            const SizedBox(height: 15),
            if (docs.where((d) => (d['currentStock'] ?? 0) <= 10).isEmpty)
              _buildEmptyAlert()
            else
              ...docs.where((d) => (d['currentStock'] ?? 0) <= 10).map((d) =>
                  _buildModernAlertTile(d['productName'], "${d['currentStock']} units left in stock", Icons.warning_amber_rounded, Colors.red)
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyAlert() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
      child: const Center(child: Text("All stock levels are healthy! ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildPremiumStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white60, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildCleanBarChart(Map<String, double> data) {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
      ),
      child: BarChart(
        BarChartData(
          maxY: data.values.isEmpty ? 10 : data.values.reduce((a, b) => a > b ? a : b) * 1.3,
          barGroups: data.entries.map((e) => BarChartGroupData(
            x: data.keys.toList().indexOf(e.key),
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: const Color(0xFF233E99),
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              )
            ],
          )).toList(),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  if (v.toInt() >= data.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(data.keys.elementAt(v.toInt()).substring(0, 3).toUpperCase(),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w900)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: Colors.grey.shade400))),
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade50, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildModernAlertTile(String name, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1C1E))),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
        ],
      ),
    );
  }
}

// ======================== TAB 2: FORECAST ========================
class _ForecastReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _ForecastReportTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('forecasts').orderBy('forecastDate', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return _buildEmptyState("No forecast data available yet.");

        final docs = snapshot.data!.docs;
        List<FlSpot> spots = [];
        double maxDemand = 0;

        for (int i = 0; i < docs.length; i++) {
          final data = docs[i].data() as Map<String, dynamic>;
          double val = double.tryParse(data['predictedDemand']?.toString() ?? '0') ?? 0;
          if (val > maxDemand) maxDemand = val;
          spots.add(FlSpot(i.toDouble(), val));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildHeader("Demand Prediction Trend"),
            const SizedBox(height: 20),
            _buildLineChart(spots, maxDemand),
            const SizedBox(height: 35),
            _buildHeader("Upcoming Predictions"),
            const SizedBox(height: 15),
            ...docs.take(10).map((d) {
              final data = d.data() as Map<String, dynamic>;

              String dateStr = "N/A";
              if (data['forecastDate'] is Timestamp) {
                dateStr = DateFormat('dd MMM yyyy').format((data['forecastDate'] as Timestamp).toDate());
              }

              return _buildForecastTile(
                  dateStr,
                  data['productName'] ?? 'Unknown Product',
                  data['predictedDemand']?.toString() ?? "0"
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(child: Text(msg, style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)));
  }

  Widget _buildHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)));
  }

  Widget _buildLineChart(List<FlSpot> spots, double maxY) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: LineChart(
        LineChartData(
          minX: 0, maxX: (spots.length - 1).toDouble(),
          minY: 0, maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.purpleAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.purpleAccent.withOpacity(0.1)),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)))),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildForecastTile(String date, String productName, String demand) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.trending_up_rounded, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text("Date: $date", style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(demand, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.purple)),
              const Text("units", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }
}

// ======================== TAB 3: RISK (UPDATED) ========================
class _RiskReportTab extends StatelessWidget {
  final FirebaseFirestore db;
  const _RiskReportTab({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('risk_analysis').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No risk data detected.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));

        final docs = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildRiskHeader(docs.length),
            const SizedBox(height: 30),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              // [FIX] Masukkan productName kalau ada, kalau tak letak unknown
              return _buildRiskTile(
                data['ProductName'] ?? 'Unknown Product', // Updated key to ProductName based on Firestore data
                data['RiskID'] ?? 'Unknown Risk', // Updated key to RiskID based on Firestore data
                "Risk Value: ${data['RiskValue']}", // Updated to display RiskValue
                data['RiskLevel'] ?? 'Low', // Updated key to RiskLevel based on Firestore data
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildRiskHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: const Color(0xFFD32F2F).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.security_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Identified Risks", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              Text("$count Items", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  // --- [FIX] UI RISK TILE DENGAN PRODUCT NAME ---
  Widget _buildRiskTile(String productName, String risk, String impact, String probability) {
    Color riskColor = Colors.green;
    String prob = probability.toLowerCase();
    if (prob.contains('high')) riskColor = const Color(0xFFD32F2F);
    else if (prob.contains('medium')) riskColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: riskColor.withOpacity(0.2), width: 1),
        boxShadow: [BoxShadow(color: riskColor.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Product Name & Probability
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(probability.toUpperCase(), style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Product Name (Main Title)
          Text(productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),

          const SizedBox(height: 6),

          // Row 3: Risk Factor (Subtitle Warna Merah/Oren sikit)
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: riskColor),
              const SizedBox(width: 5),
              Expanded(child: Text(risk, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: riskColor))),
            ],
          ),

          const SizedBox(height: 4),

          // Row 4: Impact (Grey text)
          Text(impact, style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4)),
        ],
      ),
    );
  }
}