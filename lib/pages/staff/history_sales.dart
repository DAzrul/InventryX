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
  final Color primaryBlue = const Color(0xFF20338F);
  final Color accentBlue = const Color(0xFF3B5BDB);
  final Color bgLight = const Color(0xFFF8F9FD);

  String selectedFilter = "Last 7 Days";
  DateTime? customStartDate;
  DateTime? customEndDate;

  Future<void> _selectDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: customStartDate != null && customEndDate != null
          ? DateTimeRange(start: customStartDate!, end: customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            useMaterial3: true,
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 30),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        customStartDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        customEndDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        selectedFilter = "Custom";
      });
    }
  }

  Query _getSalesQuery() {
    CollectionReference salesRef = FirebaseFirestore.instance.collection('sales');
    DateTime now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (selectedFilter == "Last 7 Days") {
      DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
      start = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day, 0, 0, 0);
    } else if (selectedFilter == "Last 30 Days") {
      DateTime thirtyDaysAgo = now.subtract(const Duration(days: 30));
      start = DateTime(thirtyDaysAgo.year, thirtyDaysAgo.month, thirtyDaysAgo.day, 0, 0, 0);
    } else if (selectedFilter == "Custom") {
      start = customStartDate ?? start;
      end = customEndDate ?? end;
    }

    return salesRef
        .where('status', isEqualTo: 'completed')
        .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('saleDate', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Sales Insights",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getSalesQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return _buildEmptyState();

                double totalRevenue = 0;
                Map<String, Map<String, dynamic>> dailySummary = {};

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  DateTime date = (data['saleDate'] as Timestamp).toDate();
                  String dateKey = DateFormat('dd/MM/yyyy').format(date);
                  double amount = (data['totalAmount'] ?? 0).toDouble();
                  int qty = (data['quantitySold'] ?? 0).toInt();
                  String pID = data['productID'] ?? 'Unknown';

                  totalRevenue += amount;

                  if (dailySummary.containsKey(dateKey)) {
                    dailySummary[dateKey]!['totalAmount'] += amount;
                    dailySummary[dateKey]!['totalQty'] += qty;
                    dailySummary[dateKey]!['transactionCount'] += 1;
                    (dailySummary[dateKey]!['uniqueProducts'] as Set).add(pID);
                  } else {
                    dailySummary[dateKey] = {
                      'date': dateKey,
                      'rawDate': date,
                      'totalAmount': amount,
                      'totalQty': qty,
                      'transactionCount': 1,
                      'uniqueProducts': {pID},
                    };
                  }
                }

                List<Map<String, dynamic>> summaryList = dailySummary.values.toList();
                summaryList.sort((a, b) => b['rawDate'].compareTo(a['rawDate']));

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildOverviewCard(totalRevenue, docs.length),
                    const Row(
                      children: [
                        Icon(Icons.history_rounded, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Daily History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ...summaryList.map((item) => _buildClickableListItem(context, item)).toList(),
                    const SizedBox(height: 40),
                  ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
            child: Row(
              children: [
                _buildFilterChip("Today", Icons.today),
                _buildFilterChip("Last 7 Days", Icons.date_range),
                _buildFilterChip("Last 30 Days", Icons.calendar_view_month),
                _buildFilterChip("Custom", Icons.tune, isAction: true),
              ],
            ),
          ),
          if (selectedFilter == "Custom" && customStartDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  "${DateFormat('dd MMM').format(customStartDate!)} - ${DateFormat('dd MMM yyyy').format(customEndDate!)}",
                  style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, {bool isAction = false}) {
    bool isSel = selectedFilter == label;
    return GestureDetector(
      onTap: () {
        if (label == "Custom") _selectDateRange();
        else {
          setState(() {
            selectedFilter = label;
            customStartDate = null;
            customEndDate = null;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSel ? primaryBlue : Colors.grey.shade200),
          boxShadow: isSel ? [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSel ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontSize: 13, fontWeight: isSel ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(double total, int count) {
    // Generate the dynamic date range label
    String dateRangeLabel = "";
    DateTime now = DateTime.now();

    if (selectedFilter == "Today") {
      dateRangeLabel = DateFormat('dd MMM yyyy').format(now);
    } else if (selectedFilter == "Last 7 Days") {
      DateTime start = now.subtract(const Duration(days: 7));
      dateRangeLabel = "${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(now)}";
    } else if (selectedFilter == "Last 30 Days") {
      DateTime start = now.subtract(const Duration(days: 30));
      dateRangeLabel = "${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(now)}";
    } else if (selectedFilter == "Custom" && customStartDate != null && customEndDate != null) {
      dateRangeLabel = "${DateFormat('dd MMM').format(customStartDate!)} - ${DateFormat('dd MMM yyyy').format(customEndDate!)}";
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [primaryBlue, accentBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: primaryBlue.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Revenue",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              // Display the date range label in the top right of the card
              Text(dateRangeLabel,
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text("RM ${total.toStringAsFixed(2)}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
            child: Text("$count Transactions Found",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildClickableListItem(BuildContext context, Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SalesDetailsPage(selectedDate: item['date']))),
        borderRadius: BorderRadius.circular(20),
        child: _SummaryCard(
          date: item['date'],
          amount: "RM ${item['totalAmount'].toStringAsFixed(2)}",
          transactions: item['transactionCount'].toString(),
          unitsSold: item['totalQty'].toString(),
          itemsSold: (item['uniqueProducts'] as Set).length.toString(),
          primaryColor: primaryBlue,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text("No records found for this period.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String err) {
    return Center(child: Text("Error: $err", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
  }
}

class _SummaryCard extends StatelessWidget {
  final String date, amount, transactions, unitsSold, itemsSold;
  final Color primaryColor;
  const _SummaryCard({required this.date, required this.amount, required this.transactions, required this.unitsSold, required this.itemsSold, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Date", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
                ],
              ),
              Text(amount, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor)),
            ],
          ),
          const Divider(height: 30, color: Color(0xFFF1F3F5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dataPoint("Trans.", transactions, Icons.shopping_bag_outlined),
              _dataPoint("Units", unitsSold, Icons.layers_outlined),
              _dataPoint("Items", itemsSold, Icons.category_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataPoint(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}