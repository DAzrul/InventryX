import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesDetailsPage extends StatelessWidget {
  final String selectedDate;

  const SalesDetailsPage({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    // Range tarikh untuk Query
    DateTime startDate = DateFormat('dd/MM/yyyy').parse(selectedDate);
    DateTime endDate = startDate.add(const Duration(days: 1));

    // Formatted strings for the label
    String startLabel = DateFormat('dd MMM yyyy').format(startDate);
    String endLabel = DateFormat('dd MMM yyyy').format(endDate.subtract(const Duration(seconds: 1)));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Transaction Details",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // NEW: Date Range Label Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  "Showing records for: ",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  startLabel, // Displays the selected date clearly
                  style: const TextStyle(color: Color(0xFF20338F), fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Expanded StreamBuilder
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sales')
                  .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
                  .where('saleDate', isLessThan: Timestamp.fromDate(endDate))
                  .orderBy('saleDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No detailed records."));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    String productName = data['snapshotName'] ?? "Unknown Product";
                    int qty = data['quantitySold'] ?? 0;
                    double total = (data['totalAmount'] ?? 0).toDouble();
                    Timestamp time = data['saleDate'];
                    String formattedTime = DateFormat('hh:mm a').format(time.toDate());

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF20338F).withOpacity(0.1),
                          child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF20338F)),
                        ),
                        title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Qty: $qty units", style: const TextStyle(fontSize: 12)),
                        trailing: Text("RM${total.toStringAsFixed(2)}",
                            style: const TextStyle(color: Color(0xFF20338F), fontWeight: FontWeight.bold)),
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
}