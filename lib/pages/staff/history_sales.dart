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
  // Warna tema aplikasi
  final Color primaryBlue = const Color(0xFF20338F);
  String selectedFilter = "Last 7 Days";

  // --- LOGIC: QUERY FIREBASE ---
  Query _getSalesQuery() {
    // Pastikan collection name 'sales' sama dlm Firebase kau mat
    CollectionReference salesRef = FirebaseFirestore.instance.collection('sales');
    DateTime now = DateTime.now();
    DateTime startOfPeriod;

    if (selectedFilter == "Today") {
      startOfPeriod = DateTime(now.year, now.month, now.day);
    } else if (selectedFilter == "Last 7 Days") {
      startOfPeriod = now.subtract(const Duration(days: 7));
    } else {
      // Last 30 Days
      startOfPeriod = now.subtract(const Duration(days: 30));
    }

    // Hanya ambil jualan yang 'completed' dan ikut tarikh filter
    return salesRef
        .where('status', isEqualTo: 'completed')
        .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod))
        .orderBy('saleDate', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // Background kelabu lembut sikit
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Sales History",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getSalesQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Fucked up mat: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No sales records found.", style: TextStyle(color: Colors.grey)));
                }

                // --- AGGREGATION: GROUP BY DATE ---
                // Sebab jualan mungkin banyak dlm sehari, kita group-kan dlm Card harian
                Map<String, Map<String, dynamic>> dailySummary = {};

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  DateTime date = (data['saleDate'] as Timestamp).toDate();
                  String dateKey = DateFormat('dd/MM/yyyy').format(date);

                  double amount = (data['totalAmount'] ?? 0).toDouble();
                  int qty = (data['quantitySold'] ?? 0).toInt();
                  String productId = data['productID'] ?? 'Unknown';

                  if (dailySummary.containsKey(dateKey)) {
                    dailySummary[dateKey]!['totalAmount'] += amount;
                    dailySummary[dateKey]!['totalQty'] += qty;
                    dailySummary[dateKey]!['transactionCount'] += 1;
                    (dailySummary[dateKey]!['uniqueProducts'] as Set<String>).add(productId);
                  } else {
                    dailySummary[dateKey] = {
                      'date': dateKey,
                      'rawDate': date, // Simpan untuk sorting nanti
                      'totalAmount': amount,
                      'totalQty': qty,
                      'transactionCount': 1,
                      'uniqueProducts': {productId},
                    };
                  }
                }

                // Susun balik list ikut tarikh terbaru
                List<Map<String, dynamic>> summaryList = dailySummary.values.toList();
                summaryList.sort((a, b) => b['rawDate'].compareTo(a['rawDate']));

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: summaryList.length,
                  itemBuilder: (context, index) {
                    final item = summaryList[index];
                    int productCount = (item['uniqueProducts'] as Set<String>).length;

                    return GestureDetector(
                      onTap: () {
                        // Pass string date "dd/MM/yyyy" ke page details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesDetailsPage(selectedDate: item['date']),
                          ),
                        );
                      },
                      child: _SummaryCard(
                        date: item['date'],
                        amount: "RM ${item['totalAmount'].toStringAsFixed(2)}",
                        transactions: item['transactionCount'].toString(),
                        unitsSold: item['totalQty'].toString(),
                        itemsSold: productCount.toString(),
                        primaryColor: primaryBlue,
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ["Today", "Last 7 Days", "Last 30 Days"]
            .map((label) => _buildFilterChip(label)).toList(),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
            )
        ),
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
  final Color primaryColor;

  const _SummaryCard({
    required this.date,
    required this.amount,
    required this.transactions,
    required this.unitsSold,
    required this.itemsSold,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Sales Date", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                ],
              ),
              Text(amount, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dataPoint("Transactions", transactions),
              _dataPoint("Units Sold", unitsSold),
              _dataPoint("Products", itemsSold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataPoint(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}