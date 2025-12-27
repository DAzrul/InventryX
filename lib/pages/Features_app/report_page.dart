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

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFF233E99).withOpacity(0.1), // [FIX] Guna withOpacity mat!
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.file_download_outlined, color: Color(0xFF233E99), size: 22),
              ),
              onPressed: () => _showExportOptions(context),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab, // Tab indicator full bwh label
          indicatorWeight: 4,
          indicatorColor: const Color(0xFF233E99),
          labelColor: const Color(0xFF233E99),
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: const [Tab(text: "Inventory"), Tab(text: "Forecast"), Tab(text: "Risk")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InventoryReportTab(db: _db),
          _buildPlaceholderTab("Forecast Analysis Coming Soon"),
          _buildPlaceholderTab("Risk Assessment Coming Soon"),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 60, color: Colors.grey.shade200),
          const SizedBox(height: 15),
          Text(text, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Supaya design rounded nampak mat
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

// ======================== TAB: INVENTORY ========================
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
            _buildPremiumStatCard("Estimated Asset Value", "RM ${totalValue.toStringAsFixed(2)}"),
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
                  _buildModernAlertTile(d['productName'], "${d['currentStock']} units left in stock")
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

  Widget _buildPremiumStatCard(String title, String val) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF233E99), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: const Color(0xFF233E99).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white60, size: 18),
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

  Widget _buildModernAlertTile(String name, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.red.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1C1E))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
        ],
      ),
    );
  }
}