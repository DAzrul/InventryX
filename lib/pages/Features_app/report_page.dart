import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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
      backgroundColor: const Color(0xFFF8FAFF), // Background lebih soft
      appBar: AppBar(
        title: const Text("Reports & Analytics",
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E), fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Butang Export yang lebih cantik
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF233E99).withValues(alpha: 0.1),
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
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          indicatorColor: const Color(0xFF233E99),
          labelColor: const Color(0xFF233E99),
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
    return Center(child: Text(text, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)));
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("Export Inventory Report", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 25),
            _exportTile(Icons.picture_as_pdf_rounded, "Export as PDF", Colors.red, () { Navigator.pop(ctx); }),
            const SizedBox(height: 12),
            _exportTile(Icons.table_chart_rounded, "Export as Excel", Colors.green, () { Navigator.pop(ctx); }),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _exportTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade100),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 15),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ======================== TAB: INVENTORY (KEMAS UI) ========================
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
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          children: [
            // Summary Card dengan Gradient
            _buildPremiumStatCard("Total Inventory Value", "RM ${totalValue.toStringAsFixed(2)}"),

            const SizedBox(height: 30),
            _sectionHeader("Stock Distribution"),
            const SizedBox(height: 15),
            _buildCleanBarChart(catData),

            const SizedBox(height: 30),
            _sectionHeader("Critical Low Stock"),
            const SizedBox(height: 12),
            ...docs.where((d) => (d['currentStock'] ?? 0) <= 10).map((d) =>
                _buildModernAlertTile(d['productName'], "${d['currentStock']} units remaining")
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5));
  }

  Widget _buildPremiumStatCard(String title, String val) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF233E99), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF233E99).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCleanBarChart(Map<String, double> data) {
    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(15, 25, 15, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: BarChart(
        BarChartData(
          maxY: data.values.isEmpty ? 10 : data.values.reduce((a, b) => a > b ? a : b) * 1.2,
          barGroups: data.entries.map((e) => BarChartGroupData(
            x: data.keys.toList().indexOf(e.key),
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: const Color(0xFF233E99),
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: Colors.grey.shade50),
              )
            ],
          )).toList(),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(data.keys.elementAt(v.toInt()), style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: Colors.grey.shade300))),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}