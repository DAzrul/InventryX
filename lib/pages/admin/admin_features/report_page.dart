import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String selectedFilter = 'Admin'; // State untuk Filter
  final List<String> adminFilters = ['Admin', 'Manager', 'Staff'];

  // Data Dummy untuk Ringkasan Produk
  final List<Map<String, dynamic>> productData = const [
    {'id': 'SKU001', 'product': 'Mechanical Keyboard', 'quantity': 150},
    {'id': 'SKU002', 'product': 'RGB Gaming Mouse', 'quantity': 45},
    {'id': 'SKU003', 'product': 'Monitor Ultra-Lebar', 'quantity': 12},
    {'id': 'SKU004', 'product': 'Fon Kepala Tanpa Wayar', 'quantity': 200},
    {'id': 'SKU005', 'product': 'Webcam HD 1080p', 'quantity': 70},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Reports', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. FILTER DROPDOWN ---
            _buildFilterDropdown(),
            const SizedBox(height: 15),

            // --- 2. METRICS OVERVIEW ---
            const Text('Metrics Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildMetricsOverview(),
            const SizedBox(height: 25),

            // --- 3. INVENTORY TRENDS (Bar Chart Placeholder) ---
            const Text('Inventory Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildInventoryTrendsChart(),
            const SizedBox(height: 25),

            // --- 4. FORECAST VS ACTUAL (Line Chart Placeholder & Actions) ---
            _buildForecastVsActualChart(),
            const SizedBox(height: 25),

            // --- 5. STOCK & PRODUCT DATA TABLE ---
            const Text('Stock & Product Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _buildProductSummaryList(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- Widget Pembantu ---

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedFilter,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF233E99)),
          style: const TextStyle(color: Colors.black, fontSize: 16),
          onChanged: (String? newValue) {
            setState(() {
              selectedFilter = newValue!;
            });
          },
          items: adminFilters.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text('Filter $value'),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMetricsOverview() {
    return Column(
      children: const [
        MetricCard(
          title: 'Total Stock',
          value: '2,345 units',
          trend: '+12% last month',
          icon: Icons.inventory_2_outlined,
          tag: 'Admin',
          tagColor: Color(0xFFE53935), // Merah
          trendColor: Colors.green,
        ),
        MetricCard(
          title: 'Low Stock SKU',
          value: '18 SKU',
          trend: '-5% from last week',
          icon: Icons.error_outline,
          tag: 'Manager',
          tagColor: Color(0xFF607D8B), // Biru Kelabu
          trendColor: Colors.red,
        ),
        MetricCard(
          title: 'Incoming Orders',
          value: '78 orders',
          trend: '+8% from yesterday',
          icon: Icons.local_shipping_outlined,
          tag: 'user',
          tagColor: Color(0xFF9E9E9E), // Kelabu
          trendColor: Colors.green,
        ),
        MetricCard(
          title: 'Forecast Request',
          value: '3,100 Units',
          trend: '+15% next month',
          icon: Icons.show_chart,
          tag: 'Admin',
          tagColor: Color(0xFFE53935), // Merah
          trendColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildInventoryTrendsChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Monthly Inventory & Forecast', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        // Carta Bar Placeholder
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Image.asset('assets/bar_chart_placeholder.png', fit: BoxFit.contain), // Gantikan dengan carta sebenar
        ),
      ],
    );
  }

  Widget _buildForecastVsActualChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Forecast vs. Actual (Order)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        // Carta Garisan Placeholder
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Image.asset('assets/line_chart_placeholder.png', fit: BoxFit.contain), // Gantikan dengan carta sebenar
        ),
        const SizedBox(height: 15),

        // Butang Export
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('Export CSV', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('Export PDF', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 40,
              width: 40,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.refresh, color: Colors.black),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductSummaryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.widgets, color: Colors.black54, size: 20), // Ikon baru
            SizedBox(width: 8),
            Text('Product Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),

        // Header Jadual
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: const [
                    Icon(Icons.view_module, size: 18, color: Color(0xFF233E99)), // Ikon baru untuk ID
                    SizedBox(width: 4),
                    Text('ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const Expanded(flex: 4, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const Expanded(flex: 3, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const Expanded(flex: 3, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),

        // Baris Data
        ...productData.map((data) => Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5))),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 2, child: Text(data['id'].toString(), style: const TextStyle(fontSize: 13))),
              Expanded(flex: 4, child: Text(data['product'].toString(), style: const TextStyle(fontSize: 13))),
              Expanded(flex: 3, child: Text(data['quantity'].toString(), style: const TextStyle(fontSize: 13))),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // Letakkan ikon ke kanan
                  children: [
                    // Ikon: Edit, View (Eye), Log/List
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.remove_red_eye_outlined, size: 20), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.list_alt, size: 20, color: Colors.black54), onPressed: () {}), // Ikon Log
                  ],
                ),
              ),
            ],
          ),
        )).toList(),

        // Paging/Navigasi (Next/Previous)
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(onPressed: () {}, child: const Text('Before')),
            const SizedBox(width: 8),
            // Button Halaman Semasa (1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF233E99), borderRadius: BorderRadius.circular(4)),
              child: const Text('1', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () {}, child: const Text('2')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () {}, child: const Text('Next')),
          ],
        ),
      ],
    );
  }
}

// Widget Reusable untuk Kad Metrik
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final IconData icon;
  final String tag;
  final Color tagColor;
  final Color trendColor;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    required this.tag,
    required this.tagColor,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: const Color(0xFF233E99)),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                // Tag (Admin/Manager/User)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // Trend Line
            Row(
              children: [
                Text(
                  trend,
                  style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 4),
                const Text('Current Trends', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}