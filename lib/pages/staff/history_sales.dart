import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'sales_details.dart';

class HistorySalesPage extends StatefulWidget {
  const HistorySalesPage({super.key});

  @override
  State<HistorySalesPage> createState() => _HistorySalesPageState();
}

class _HistorySalesPageState extends State<HistorySalesPage> {
  String selectedFilter = "Last 7 Days";

  Query _getSalesQuery() {
    CollectionReference salesRef = FirebaseFirestore.instance.collection('sales');
    DateTime now = DateTime.now();
    DateTime startOfPeriod;

    if (selectedFilter == "Today") {
      startOfPeriod = DateTime(now.year, now.month, now.day);
    } else if (selectedFilter == "Last 7 Days") {
      startOfPeriod = now.subtract(const Duration(days: 7));
    } else {
      startOfPeriod = now.subtract(const Duration(days: 30));
    }

    return salesRef
        .where('saleDate', isGreaterThanOrEqualTo: startOfPeriod)
        .orderBy('saleDate', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Sales Summary",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getSalesQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("Tiada rekod jualan."));

                // --- LOGIK AGGREGATION (Grouping by Date) ---
                Map<String, Map<String, dynamic>> dailySummary = {};

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  DateTime date = (data['saleDate'] as Timestamp).toDate();
                  String dateKey = DateFormat('dd/MM/yyyy').format(date);

                  // Guna totalAmount dari DB atau kira (Price * Qty)
                  double amount = (data['totalAmount'] ?? 0).toDouble();
                  int qty = data['quantitySold'] ?? 0;
                  String productId = data['productID'] ?? 'Unknown';

                  if (dailySummary.containsKey(dateKey)) {
                    dailySummary[dateKey]!['totalAmount'] += amount;
                    dailySummary[dateKey]!['totalQty'] += qty;
                    dailySummary[dateKey]!['transactionCount'] += 1;
                    (dailySummary[dateKey]!['uniqueProducts'] as Set<String>).add(productId);
                  } else {
                    dailySummary[dateKey] = {
                      'date': dateKey,
                      'totalAmount': amount,
                      'totalQty': qty,
                      'transactionCount': 1,
                      'uniqueProducts': {productId},
                    };
                  }
                }

                List<Map<String, dynamic>> summaryList = dailySummary.values.toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: summaryList.length,
                  itemBuilder: (context, index) {
                    final item = summaryList[index];
                    int productCount = (item['uniqueProducts'] as Set<String>).length;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesDetailsPage(selectedDate: item['date']), // 'item['date']' adalah string "dd/MM/yyyy"
                          ),
                        );
                      },
                      child: _SummaryCard(
                        date: item['date'],
                        amount: "RM${item['totalAmount'].toStringAsFixed(2)}",
                        transactions: item['transactionCount'].toString(),
                        unitsSold: item['totalQty'].toString(),
                        itemsSold: productCount.toString(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: ["Today", "Last 7 Days", "Last 30 Days"]
            .map((label) => _buildFilterChip(label)).toList(),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF20338F) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black54, fontSize: 12)),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String date;
  final String amount;
  final String transactions;
  final String unitsSold;
  final String itemsSold;

  const _SummaryCard({
    required this.date,
    required this.amount,
    required this.transactions,
    required this.unitsSold,
    required this.itemsSold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
              Text(amount, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF20338F))),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dataPoint("Transactions", transactions),
              _dataPoint("Units Sold", unitsSold),
              _dataPoint("Items Sold", itemsSold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataPoint(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}