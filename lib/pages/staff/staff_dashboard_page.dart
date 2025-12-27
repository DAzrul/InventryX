import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../Features_app/barcode_scanner_page.dart';
import 'stock_out.dart';
import 'daily_sales.dart';

class StaffDashboardPage extends StatefulWidget {
  final String username;
  const StaffDashboardPage({super.key, required this.username});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  String _selectedHistoryFilter = "Last 7 Days";

  // --- LOGIC: QUERY UNTUK POPUP HISTORY ---
  Query _getHistoryQuery() {
    CollectionReference moveRef = FirebaseFirestore.instance.collection('stockMovements');
    DateTime now = DateTime.now();
    DateTime startOfPeriod;

    if (_selectedHistoryFilter == "Today") {
      startOfPeriod = DateTime(now.year, now.month, now.day);
    } else if (_selectedHistoryFilter == "Last 7 Days") {
      startOfPeriod = now.subtract(const Duration(days: 7));
    } else {
      startOfPeriod = now.subtract(const Duration(days: 30));
    }

    return moveRef
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod))
        .orderBy('timestamp', descending: true);
  }

  // --- LOGIC: POPUP FULL HISTORY ---
  void _showAllActivityPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("Stock Movement History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ["Today", "Last 7 Days", "Last 30 Days"].map((label) {
                    bool isSel = _selectedHistoryFilter == label;
                    return GestureDetector(
                      onTap: () {
                        setModalState(() => _selectedHistoryFilter = label);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF203288) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSel ? Colors.transparent : Colors.grey.shade300),
                        ),
                        child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black54, fontSize: 13, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getHistoryQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("No movements found."));
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final int qty = data['quantity'] ?? 0;
                        return _buildActivityItem(
                          title: "${data['type']}: ${data['productName']}",
                          subtitle: DateFormat('dd MMM yyyy, hh:mm a').format((data['timestamp'] as Timestamp).toDate()),
                          trailingText: qty > 0 ? "+$qty units" : "$qty units",
                          trailingColor: qty > 0 ? Colors.green : Colors.red,
                          icon: qty > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF203288);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(primaryBlue),
          const SizedBox(height: 30),

          Row(
            children: [
              _buildStatCard(
                stream: FirebaseFirestore.instance.collection('products').snapshots(),
                icon: Icons.arrow_circle_down_outlined,
                label: "Low Stock",
                calcLogic: (docs) => docs.where((d) => (d['currentStock'] ?? 0) <= (d['reorderLevel'] ?? 0)).length,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                stream: FirebaseFirestore.instance.collection('batches').where('currentQuantity', isGreaterThan: 0).snapshots(),
                icon: Icons.access_time,
                label: "Expiring Soon",
                calcLogic: (docs) {
                  final now = DateTime.now();
                  final next30Days = now.add(const Duration(days: 30));
                  return docs.where((d) {
                    DateTime exp = (d['expiryDate'] as Timestamp).toDate();
                    return exp.isAfter(now) && exp.isBefore(next30Days);
                  }).length;
                },
              ),
            ],
          ),

          const SizedBox(height: 30),
          const Text("Quick Action", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          _buildQuickActionButton(title: "Scan Item/ Check Stock", subtitle: "Scan barcode to view details", icon: Icons.qr_code_scanner, color: primaryBlue, onTap: () {}),
          const SizedBox(height: 16),
          _buildQuickActionButton(title: "Record Daily Sales", subtitle: "Deduct stock by jualan", icon: Icons.note_add_outlined, color: primaryBlue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailySalesPage()))),

          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => _showAllActivityPopup(context), child: Text("View All", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold))),
            ],
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('stockMovements').orderBy('timestamp', descending: true).limit(5).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final int qty = data['quantity'] ?? 0;
                  return _buildActivityItem(
                    title: "${data['type']}: ${data['productName']}",
                    subtitle: DateFormat('hh:mm a').format((data['timestamp'] as Timestamp).toDate()),
                    trailingText: qty > 0 ? "+$qty units" : "$qty units",
                    trailingColor: qty > 0 ? Colors.green : Colors.red,
                    icon: qty > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- HELPERS (HEADER REPAIRED) ---
  Widget _buildHeaderSection(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('username', isEqualTo: widget.username).limit(1).snapshots(),
      builder: (context, snapshot) {
        String name = widget.username; String? img;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          var d = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          name = d['username'] ?? name; img = d['profilePictureUrl'];
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 2)
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: (img != null && img.isNotEmpty) ? NetworkImage(img) : null,
                    // [FIX] Tunjuk Icon Person ikut design Admin Dashboard
                    child: (img == null || img.isEmpty)
                        ? Icon(Icons.person_rounded, color: primaryColor.withValues(alpha: 0.4))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, d MMM').format(DateTime.now()),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    Text("Hi, $name", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const Icon(Icons.notifications_none_rounded, size: 28, color: Colors.grey)
          ],
        );
      },
    );
  }

  Widget _buildStatCard({required Stream<QuerySnapshot> stream, required IconData icon, required String label, required int Function(List<QueryDocumentSnapshot>) calcLogic}) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          int count = 0;
          if (snapshot.hasData) count = calcLogic(snapshot.data!.docs);
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 28, color: Colors.black87), const SizedBox(height: 16), Text("$count Items", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(icon, color: Colors.white, size: 30), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11))])), const Icon(Icons.chevron_right, color: Colors.white)])));
  }

  Widget _buildActivityItem({required String title, required String subtitle, required String trailingText, required Color trailingColor, required IconData icon}) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
        child: Row(children: [CircleAvatar(backgroundColor: const Color(0xFFF5F5F5), child: Icon(icon, color: trailingColor, size: 20)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11))])), Text(trailingText, style: TextStyle(color: trailingColor, fontWeight: FontWeight.bold, fontSize: 14))])
    );
  }
}