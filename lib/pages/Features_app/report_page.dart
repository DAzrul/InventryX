import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Pastikan anda tambah fl_chart di pubspec.yaml

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 3 Tab utama berdasarkan Proposal (Inventory, Forecast, Risk)
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
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: const Text("Reports & Analytics", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Butang Export PDF/Excel (Keperluan Proposal)
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF233E99)),
            tooltip: "Export Report",
            onPressed: () {
              // Logik Export PDF/Excel akan diletakkan di sini
              _showExportDialog(context);
            },
          ),
          const SizedBox(width: 10),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF233E99),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF233E99),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Inventory"),
            Tab(text: "Forecast"),
            Tab(text: "Risk"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _InventoryReportTab(),
          _ForecastReportTab(),
          _RiskReportTab(),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Export Report"),
        content: const Text("Choose format to export:"),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            label: const Text("PDF"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton.icon(
            icon: const Icon(Icons.table_chart, color: Colors.green),
            label: const Text("Excel"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}

// --- TAB 1: INVENTORY REPORT ---
class _InventoryReportTab extends StatelessWidget {
  const _InventoryReportTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard("Total Stock Value", "RM 45,230.00", Colors.blue),
          const SizedBox(height: 20),

          const Text("Stock Level by Category", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // Carta Bar Mudah (Contoh)
          Container(
            height: 200,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        switch(val.toInt()) {
                          case 0: return const Text("Drink", style: TextStyle(fontSize: 10));
                          case 1: return const Text("Food", style: TextStyle(fontSize: 10));
                          case 2: return const Text("Snack", style: TextStyle(fontSize: 10));
                        }
                        return const Text("");
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 80, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 50, color: Colors.orange, width: 20, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 65, color: Colors.green, width: 20, borderRadius: BorderRadius.circular(4))]),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text("Low Stock Alert", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildListItem("Coca Cola 1.5L", "5 units left", Colors.red),
          _buildListItem("Gardenia Bread", "2 units left", Colors.red),
        ],
      ),
    );
  }
}

// --- TAB 2: FORECAST REPORT ---
class _ForecastReportTab extends StatelessWidget {
  const _ForecastReportTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard("Predicted Demand (Next Month)", "1,200 Units", Colors.purple),
          const SizedBox(height: 20),

          const Text("Demand Trend (SMA Analysis)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // Line Chart Placeholder
          Container(
            height: 200,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [FlSpot(0, 1), FlSpot(1, 3), FlSpot(2, 2), FlSpot(3, 5), FlSpot(4, 4)],
                    isCurved: true,
                    color: Colors.purple,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text("Top Predicted Items", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _buildListItem("Mineral Water 500ml", "High Demand (+15%)", Colors.green),
          _buildListItem("Instant Noodle", "Stable", Colors.blue),
        ],
      ),
    );
  }
}

// --- TAB 3: RISK REPORT ---
class _RiskReportTab extends StatelessWidget {
  const _RiskReportTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildSummaryCard("High Risk Items", "12 SKUs", Colors.redAccent)),
              const SizedBox(width: 15),
              Expanded(child: _buildSummaryCard("Potential Loss", "RM 450", Colors.orange)),
            ],
          ),
          const SizedBox(height: 20),

          const Text("Expiry Risk Analysis", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildRiskItem("Fresh Milk", "Expiring in 2 days", "Critical", Colors.red),
          _buildRiskItem("Sandwich Tuna", "Expiring in 3 days", "High", Colors.orange),
          _buildRiskItem("Yogurt Drink", "Expiring in 5 days", "Medium", Colors.yellow[800]!),
        ],
      ),
    );
  }

  Widget _buildRiskItem(String title, String subtitle, String riskLevel, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(riskLevel, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}

// --- SHARED WIDGETS ---
Widget _buildSummaryCard(String title, String value, Color color) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70)),
      ],
    ),
  );
}

Widget _buildListItem(String title, String subtitle, Color color) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
    ),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(Icons.circle, color: color, size: 12)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: color)),
    ),
  );
}