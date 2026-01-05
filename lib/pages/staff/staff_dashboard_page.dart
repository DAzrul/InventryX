import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Features_app/barcode_scanner_page.dart';
import 'daily_sales.dart';
import '../notifications/notification_page.dart';

class StaffDashboardPage extends StatefulWidget {
  final String username;
  const StaffDashboardPage({super.key, required this.username});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  String _selectedHistoryFilter = "Last 7 Days";
  final Color primaryBlue = const Color(0xFF203288);

  // --- LOGIC 1: QUERY HISTORY ---
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

  // --- [FIXED] LOGIC 2: SCAN BARCODE (String & Number Check) ---
  Future<void> _scanAndShowDetails() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {

      // 1. Cuba cari sebagai STRING dulu (e.g., "955...")
      var snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('barcodeNo', isEqualTo: scannedCode)
          .limit(1)
          .get();

      // 2. Kalau tak jumpa, cuba cari sebagai NUMBER (e.g., 955...)
      if (snapshot.docs.isEmpty) {
        int? numericCode = int.tryParse(scannedCode);
        if (numericCode != null) {
          snapshot = await FirebaseFirestore.instance
              .collection('products')
              .where('barcodeNo', isEqualTo: numericCode)
              .limit(1)
              .get();
        }
      }

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        _showProductDetailPopup(snapshot.docs.first.data());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Product not found for barcode: $scannedCode"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- UI: POPUP PRODUCT DETAILS ---
  void _showProductDetailPopup(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),

            _buildProductImage(data['imageUrl'], size: 100),

            const SizedBox(height: 20),
            Text(data['productName'] ?? 'Unknown', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            Text("Barcode: ${data['barcodeNo'] ?? '-'}", style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDetailInfoBox("Stock", "${data['currentStock']}", Colors.blue),
                _buildDetailInfoBox("Price", "RM ${data['price']}", Colors.green),
                _buildDetailInfoBox("Category", data['category'] ?? '-', Colors.orange),
              ],
            ),

            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailInfoBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
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
                          color: isSel ? primaryBlue : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSel ? Colors.transparent : Colors.grey.shade300),
                          boxShadow: isSel ? [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
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
                          trailingText: qty > 0 ? "+$qty" : "$qty",
                          trailingColor: qty > 0 ? Colors.green : Colors.red,
                          icon: qty > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(primaryBlue),
          const SizedBox(height: 30),

          // --- STATS CARDS ---
          Row(
            children: [
              _buildStatCard(
                stream: FirebaseFirestore.instance.collection('products').snapshots(),
                icon: Icons.warning_amber_rounded,
                label: "Low Stock Alert",
                color: Colors.orange,
                calcLogic: (docs) {
                  int count = 0;
                  for (var d in docs) {
                    var data = d.data() as Map<String, dynamic>;
                    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
                    int reorderPoint = int.tryParse(data['reorderLevel']?.toString() ?? '10') ?? 10;
                    if (stock <= reorderPoint) count++;
                  }
                  return count;
                },
              ),
              const SizedBox(width: 16),
              // [FIX] Update Logic Expired untuk sama dengan Stock Page
              _buildStatCard(
                stream: FirebaseFirestore.instance.collection('batches').where('currentQuantity', isGreaterThan: 0).snapshots(),
                icon: Icons.event_busy_rounded,
                label: "Expired Items", // Tukar label supaya tepat
                color: Colors.red,
                calcLogic: (docs) {
                  final now = DateTime.now();
                  return docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    Timestamp? expT = data['expiryDate'] as Timestamp?;
                    if (expT == null) return false;

                    // Logic: Expired jika tarikh < sekarang
                    return expT.toDate().isBefore(now);
                  }).length;
                },
              ),
            ],
          ),

          const SizedBox(height: 30),
          const Text("Quick Action", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // --- QUICK ACTION BUTTONS ---
          _buildQuickActionButton(
              title: "Scan Item / Check Stock",
              subtitle: "Scan barcode to view details",
              icon: Icons.qr_code_scanner_rounded,
              color: primaryBlue,
              onTap: _scanAndShowDetails
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton(
              title: "Record Daily Sales",
              subtitle: "Record sales based on valid stock",
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF1E3A8A),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailySalesPage()))
          ),

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
                    trailingText: qty > 0 ? "+$qty" : "$qty",
                    trailingColor: qty > 0 ? Colors.green : Colors.red,
                    icon: qty > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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

  // --- HELPERS ---

  Widget _buildHeaderSection(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('username', isEqualTo: widget.username).limit(1).snapshots(),
      builder: (context, snapshot) {
        String name = widget.username;
        String? img;
        String userRole = "staff";

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          var d = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          name = d['username'] ?? name;
          img = d['profilePictureUrl'];
          userRole = d['role'] ?? "staff";
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryColor.withOpacity(0.2), width: 2)),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    backgroundImage: (img != null && img.isNotEmpty) ? NetworkImage(img) : null,
                    child: (img == null || img.isEmpty) ? Icon(Icons.person_rounded, color: primaryColor.withOpacity(0.4)) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, d MMM').format(DateTime.now()), style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                    Text("Hi, $name", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
                  ],
                ),
              ],
            ),
            _buildNotificationButton(userRole),
          ],
        );
      },
    );
  }

  Widget _buildNotificationButton(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('alerts').where('isDone', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        return Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black87, size: 24),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationPage(userRole: role))),
              ),
            ),
            if (hasUnread)
              Container(margin: const EdgeInsets.all(8), width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({required Stream<QuerySnapshot> stream, required IconData icon, required String label, required Color color, required int Function(List<QueryDocumentSnapshot>) calcLogic}) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          int count = 0;
          if (snapshot.hasData) count = calcLogic(snapshot.data!.docs);
          return Container(
            height: 140,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(icon, size: 24, color: color),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$count Items", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                    ],
                  )
                ]
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
            ),
            child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))
                          ]
                      )
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16)
                ]
            )
        )
    );
  }

  Widget _buildActivityItem({required String title, required String subtitle, required String trailingText, required Color trailingColor, required IconData icon}) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: trailingColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: trailingColor, size: 20)
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600))
          ])),
          Text(trailingText, style: TextStyle(color: trailingColor, fontWeight: FontWeight.w900, fontSize: 15))
        ])
    );
  }

  Widget _buildProductImage(String? url, {double size = 100}) {
    if (url == null || url.isEmpty) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryBlue.withOpacity(0.1), width: 1.5)),
        child: Center(child: Icon(Icons.inventory_2_rounded, color: primaryBlue.withOpacity(0.3), size: size * 0.5)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CachedNetworkImage(
        imageUrl: url, width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: size, height: size, decoration: BoxDecoration(color: Colors.grey[100])),
        errorWidget: (_, __, ___) => Container(width: size, height: size, color: Colors.grey[100], child: Icon(Icons.error, color: Colors.grey)),
      ),
    );
  }
}