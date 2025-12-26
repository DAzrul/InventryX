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
  // Filter state untuk Popup History (Default: Last 7 Days)
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
      // Last 30 Days
      startOfPeriod = now.subtract(const Duration(days: 30));
    }

    return moveRef
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod))
        .orderBy('timestamp', descending: true);
  }

  // --- LOGIC: POPUP FULL HISTORY (SWIPEABLE & FILTERABLE) ---
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

              // FILTER SECTION (Sama macam Sales History mat)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ["Today", "Last 7 Days", "Last 30 Days"].map((label) {
                    bool isSel = _selectedHistoryFilter == label;
                    return GestureDetector(
                      onTap: () {
                        setModalState(() => _selectedHistoryFilter = label);
                        setState(() {}); // Update main dashboard state if needed
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
              const SizedBox(height: 10),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getHistoryQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No movements found for this period.", style: TextStyle(color: Colors.grey))));

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final int qty = data['quantity'] ?? 0;
                        final DateTime time = (data['timestamp'] as Timestamp).toDate();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildActivityItem(
                            title: "${data['type']}: ${data['productName']}",
                            subtitle: DateFormat('dd MMM yyyy, hh:mm a').format(time),
                            trailingText: qty > 0 ? "+$qty units" : "$qty units",
                            trailingColor: qty > 0 ? Colors.green : Colors.red,
                            icon: qty > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                          ),
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

  // --- LOGIC: SCAN & CHECK STOCK ---
  Future<void> _handleScanAndCheck(BuildContext context) async {
    final scannedCode = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
    if (scannedCode == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      dynamic searchKey = int.tryParse(scannedCode) ?? scannedCode;
      final snapshot = await FirebaseFirestore.instance.collection('products').where('barcodeNo', isEqualTo: searchKey).limit(1).get();
      if (context.mounted) Navigator.pop(context);

      if (snapshot.docs.isNotEmpty) {
        if (context.mounted) _showProductDetails(context, snapshot.docs.first.data());
      } else {
        if (context.mounted) _showNotFoundDialog(context, scannedCode);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF203288);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 30),

          // 2. STATS CARDS (FIXED EXPIRING SOON)
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

          _buildQuickActionButton(title: "Scan Item/ Check Stock", subtitle: "Scan barcode to view details", icon: Icons.qr_code_scanner, color: primaryBlue, onTap: () => _handleScanAndCheck(context)),
          const SizedBox(height: 16),
          _buildQuickActionButton(title: "Record Daily Sales", subtitle: "Deduct stock by jualan", icon: Icons.note_add_outlined, color: primaryBlue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailySalesPage()))),

          const SizedBox(height: 30),

          // 4. RECENT ACTIVITY (MAIN DASHBOARD LIMIT 5)
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
              if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No recent activity."));

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final int qty = data['quantity'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildActivityItem(
                      title: "${data['type']}: ${data['productName']}",
                      subtitle: DateFormat('hh:mm a').format((data['timestamp'] as Timestamp).toDate()),
                      trailingText: qty > 0 ? "+$qty units" : "$qty units",
                      trailingColor: qty > 0 ? Colors.green : Colors.red,
                      icon: qty > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    ),
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

  // --- HELPERS (PROFIL, STAT CARD, QUICK ACTION, ACTIVITY ITEM) ---
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

  Widget _buildHeaderSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('username', isEqualTo: widget.username).limit(1).snapshots(),
      builder: (context, snapshot) {
        String name = widget.username; String? img;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          var d = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          name = d['username'] ?? name; img = d['profilePictureUrl'];
        }
        return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [CircleAvatar(radius: 22, backgroundColor: Colors.grey[200], backgroundImage: (img != null && img.isNotEmpty) ? NetworkImage(img) : null, child: img == null ? const Icon(Icons.person) : null), const SizedBox(width: 12), Text("Hi, $name", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]), const Icon(Icons.notifications_none_rounded, size: 28, color: Colors.grey)]);
      },
    );
  }

  Widget _buildQuickActionButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(icon, color: Colors.white, size: 30), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11))])), const Icon(Icons.chevron_right, color: Colors.white)])));
  }

  Widget _buildActivityItem({required String title, required String subtitle, required String trailingText, required Color trailingColor, required IconData icon}) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]), child: Row(children: [CircleAvatar(backgroundColor: const Color(0xFFF5F5F5), child: Icon(icon, color: trailingColor, size: 20)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11))])), Text(trailingText, style: TextStyle(color: trailingColor, fontWeight: FontWeight.bold, fontSize: 14))]));
  }

  void _showProductDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text(data['productName'] ?? "Details"), content: Column(mainAxisSize: MainAxisSize.min, children: [if (data['imageUrl'] != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(data['imageUrl'], height: 120, fit: BoxFit.cover)), const SizedBox(height: 10), Text("Stock: ${data['currentStock']} ${data['unit']}")]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))]));
  }

  void _showNotFoundDialog(BuildContext context, String code) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Not Found"), content: Text("No product with barcode $code"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }
}