import 'package:flutter/material.dart';
import 'sales_details.dart';

class HistorySalesPage extends StatefulWidget {
  const HistorySalesPage({super.key});

  @override
  State<HistorySalesPage> createState() => _HistorySalesPageState();
}

class _HistorySalesPageState extends State<HistorySalesPage> {
  // Track selected filter
  String selectedFilter = "Today";

  // Mock data for the history list
  final List<Map<String, String>> historyData = [
    {"date": "2023-10-26", "amount": "RM1,230.50", "items": "125"},
    {"date": "2023-10-25", "amount": "RM985.75", "items": "98"},
    {"date": "2023-10-24", "amount": "RM1,120.00", "items": "110"},
    {"date": "2023-10-23", "amount": "RM760.20", "items": "72"},
    {"date": "2023-10-22", "amount": "RM1,080.30", "items": "105"},
    {"date": "2023-10-21", "amount": "RM900.00", "items": "88"},
    {"date": "2023-10-20", "amount": "RM680.10", "items": "65"},
  ];

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
        title: const Text(
          "History",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.withOpacity(0.1), height: 1.0),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Filter Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Filter by Date:",
                  style: TextStyle(color: Colors.blueGrey, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip("Today"),
                    const SizedBox(width: 8),
                    _buildFilterChip("Last 7 Days"),
                    const SizedBox(width: 8),
                    _buildFilterChip("Last 30 Days"),
                  ],
                ),
              ],
            ),
          ),

          // 2. History List
          // inside history_sales.dart
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: historyData.length,
              itemBuilder: (context, index) {
                final item = historyData[index];
                return GestureDetector(
                  onTap: () {
                    // Navigate to Sales Details Page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SalesDetailsPage(date: item['date']!),
                      ),
                    );
                  },
                  child: _HistoryCard(
                    date: item['date']!,
                    amount: item['amount']!,
                    itemsSold: item['items']!,
                  ),
                );
              },
            ),
          ),

          // 3. Pagination Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton("1", isActive: true),
                const SizedBox(width: 10),
                _buildPageButton("2"),
                const SizedBox(width: 10),
                _buildPageButton("3"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget to build the filter buttons
  Widget _buildFilterChip(String label) {
    bool isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.grey.shade400 : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Widget for pagination numbers
  Widget _buildPageButton(String text, {bool isActive = false}) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? Colors.black : Colors.black54,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// --- History Card Widget ---

class _HistoryCard extends StatelessWidget {
  final String date;
  final String amount;
  final String itemsSold;

  const _HistoryCard({
    required this.date,
    required this.amount,
    required this.itemsSold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              Text(
                amount,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Items Sold: $itemsSold",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}