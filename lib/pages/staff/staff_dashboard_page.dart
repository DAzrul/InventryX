import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Features_app/barcode_scanner_page.dart';
import '../admin/AI_advisor_page.dart';
import 'daily_sales.dart';
import '../notifications/notification_page.dart';
// ADD THIS IMPORT
import 'low_stock_page.dart';


class StaffDashboardPage extends StatefulWidget {
  final String username;
  const StaffDashboardPage({super.key, required this.username});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  final Color primaryBlue = const Color(0xFF203288);

  // Filter States
  String _selectedHistoryFilter = "Last 7 Days";
  String _selectedMainType = "All";
  String _selectedStockOutReason = "All";
  DateTime? _customStartDate;
  DateTime? _customEndDate;

// --- UPDATED: THEMED EXPIRED ITEMS DIALOG WITH DATABASE IMAGE LOOKUP ---
  void _showExpiredItemsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.all(25),
              child: Row(
                children: [
                  Icon(Icons.event_busy_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Text("Expired Inventory", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('batches').where('currentQuantity', isGreaterThan: 0).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final now = DateTime.now();
                  final expiredDocs = snapshot.data!.docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    Timestamp? expT = data['expiryDate'] as Timestamp?;
                    return expT != null && expT.toDate().isBefore(now);
                  }).toList();

                  if (expiredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 60, color: Colors.green.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text("No expired items found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: expiredDocs.length,
                    itemBuilder: (context, index) {
                      final batchData = expiredDocs[index].data() as Map<String, dynamic>;
                      final String productId = batchData['productId'] ?? '';

                      // NESTED FUTURE BUILDER: Call product image from DB using productId
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
                        builder: (context, prodSnapshot) {
                          String imageUrl = "";
                          if (prodSnapshot.hasData && prodSnapshot.data!.exists) {
                            imageUrl = prodSnapshot.data!.get('imageUrl') ?? "";
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              children: [
                                // Product Image (Fetched from Products Collection)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 65, height: 65, fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.grey[100], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                    errorWidget: (context, url, error) => Container(color: Colors.grey[100], child: const Icon(Icons.image_not_supported_rounded)),
                                  )
                                      : Container(width: 65, height: 65, color: Colors.grey[100], child: const Icon(Icons.inventory_2_rounded, color: Colors.grey)),
                                ),
                                const SizedBox(width: 15),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(batchData['productName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1C1E))),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Expired: ${DateFormat('dd MMM yyyy').format((batchData['expiryDate'] as Timestamp).toDate())}",
                                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                // Quantity Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Text("${batchData['currentQuantity']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 14)),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- LOGIC: DATE PICKER ---
  Future<void> _selectDateRange(StateSetter setModalState) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: primaryBlue)),
        child: child!,
      ),
    );

    if (picked != null) {
      setModalState(() {
        _customStartDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _customEndDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _selectedHistoryFilter = "Custom";
      });
      setState(() {});
    }
  }

  // --- LOGIC: SMART QUERY ---
  Query _getHistoryQuery() {
    CollectionReference moveRef = FirebaseFirestore.instance.collection('stockMovements');
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (_selectedHistoryFilter == "Today") {
      start = DateTime(now.year, now.month, now.day);
    } else if (_selectedHistoryFilter == "Last 7 Days") {
      start = now.subtract(const Duration(days: 7));
    } else if (_selectedHistoryFilter == "Last 30 Days") {
      start = now.subtract(const Duration(days: 30));
    } else {
      start = _customStartDate ?? now;
      end = _customEndDate ?? now;
    }

    Query query = moveRef.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end));

    if (_selectedMainType == "Stock In") {
      query = query.where('type', isEqualTo: 'Stock In');
    } else if (_selectedMainType == "Stock Out") {
      if (_selectedStockOutReason == "All") {
        query = query.where('type', whereIn: ['Sold', 'Manual Adjustment', 'Damaged', 'Expired', 'Theft', 'Returned', 'Adjustment']);
      } else if (_selectedStockOutReason == "Sold") {
        query = query.where('type', isEqualTo: 'Sold');
      } else {
        query = query.where('type', isEqualTo: _selectedStockOutReason);
      }
    }
    return query.orderBy('timestamp', descending: true);
  }

  // --- UI: MOVEMENT HISTORY POPUP ---
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
              _buildFilterRow(["Today", "Last 7 Days", "Last 30 Days", "Custom"], _selectedHistoryFilter, (val) {
                if (val == "Custom") _selectDateRange(setModalState);
                else setModalState(() { _selectedHistoryFilter = val; });
              }),
              _buildFilterRow(["All", "Stock In", "Stock Out"], _selectedMainType, (val) {
                setModalState(() { _selectedMainType = val; _selectedStockOutReason = "All"; });
              }),
              if (_selectedMainType == "Stock Out")
                _buildFilterRow(["All", "Sold", "Damaged", "Expired", "Returned", "Theft", "Adjustment"], _selectedStockOutReason, (val) {
                  setModalState(() => _selectedStockOutReason = val);
                }, isSmall: true),
              const Divider(height: 30),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getHistoryQuery().snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("No records found."));
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final int qty = (data['quantity'] ?? 0).toInt();
                        final String type = data['type'] ?? '';
                        final String reason = data['reason'] ?? '';
                        bool isStockIn = (type == "Stock In");
                        String displayReason = isStockIn ? type : (type == "Manual Adjustment" ? reason : type);
                        return _buildActivityItem(
                          title: "${data['productName'] ?? 'Unknown'}",
                          subtitle: "$displayReason\n${DateFormat('dd MMM, hh:mm a').format((data['timestamp'] as Timestamp).toDate())}",
                          trailingText: isStockIn ? "+$qty" : "$qty",
                          trailingColor: isStockIn ? Colors.green : _getReasonColor(displayReason),
                          icon: isStockIn ? Icons.arrow_downward_rounded : _getReasonIcon(displayReason),
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

  // --- HELPERS ---
  Widget _buildFilterRow(List<String> options, String currentVal, Function(String) onSelect, {bool isSmall = false}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: options.map((label) {
          bool isSel = currentVal == label;
          return GestureDetector(
            onTap: () => onSelect(label),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSel ? primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSel ? Colors.transparent : Colors.grey.shade300),
              ),
              child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black54, fontSize: isSmall ? 11 : 13, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getReasonColor(String r) {
    String lowerR = r.toLowerCase();
    if (lowerR.contains('sold')) return Colors.redAccent;
    if (lowerR.contains('damaged')) return Colors.orange;
    if (lowerR.contains('theft')) return Colors.black87;
    if (lowerR.contains('returned')) return Colors.blue;
    if (lowerR.contains('expired')) return Colors.deepOrange;
    return Colors.red;
  }

  IconData _getReasonIcon(String r) {
    String lowerR = r.toLowerCase();
    if (lowerR.contains('stock in')) return Icons.arrow_downward_rounded;
    if (lowerR.contains('sold')) return Icons.shopping_cart_checkout;
    if (lowerR.contains('damaged')) return Icons.broken_image_rounded;
    if (lowerR.contains('theft')) return Icons.person_off_rounded;
    if (lowerR.contains('expired')) return Icons.event_busy_rounded;
    if (lowerR.contains('returned')) return Icons.keyboard_return_rounded;
    return Icons.arrow_upward_rounded;
  }

  Widget _buildErrorState(String errorMsg) {
    return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Error: $errorMsg")));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          _buildHeaderSection(primaryBlue),
          const SizedBox(height: 30),
          Row(
            children: [
              _buildStatCard(
                stream: FirebaseFirestore.instance.collection('products').snapshots(),
                icon: Icons.warning_amber_rounded,
                label: "Low Stock Alert",
                color: Colors.orange,
                // --- NAVIGATION TO LOW STOCK PAGE ---
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LowStockPage())),
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
              _buildStatCard(
                stream: FirebaseFirestore.instance.collection('batches').where('currentQuantity', isGreaterThan: 0).snapshots(),
                icon: Icons.event_busy_rounded,
                label: "Expired Items",
                color: Colors.red,
                // --- SHOW THEMED EXPIRED DIALOG ---
                onTap: _showExpiredItemsDialog,
                calcLogic: (docs) {
                  final now = DateTime.now();
                  return docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    Timestamp? expT = data['expiryDate'] as Timestamp?;
                    return expT != null && expT.toDate().isBefore(now);
                  }).length;
                },
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text("Quick Action", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          _buildQuickActionButton(
              title: "AI Restock Advisor",
              subtitle: "Check forecast & shelf life suggestions",
              icon: Icons.psychology_rounded,
              color: const Color(0xFF1E3A8A),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIAdvisorPage()))
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
                  final int qty = (data['quantity'] ?? 0).toInt();
                  final String type = data['type'] ?? '';
                  final String reason = data['reason'] ?? '';
                  bool isStockIn = (type == "Stock In");
                  String displayReason = isStockIn ? type : (type == "Manual Adjustment" ? reason : type);
                  return _buildActivityItem(
                    title: "${data['productName']}",
                    subtitle: DateFormat('hh:mm a').format((data['timestamp'] as Timestamp).toDate()),
                    trailingText: isStockIn ? "+$qty" : "$qty",
                    trailingColor: isStockIn ? Colors.green : _getReasonColor(displayReason),
                    icon: isStockIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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

  // --- UI HELPERS ---
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
            Row(children: [
              CircleAvatar(radius: 24, backgroundColor: Colors.white, backgroundImage: (img != null && img.isNotEmpty) ? NetworkImage(img) : null, child: (img == null || img.isEmpty) ? Icon(Icons.person_rounded, color: primaryColor.withOpacity(0.4)) : null),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat('EEEE, d MMM').format(DateTime.now()), style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                Text("Hi, $name", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
              ]),
            ]),
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
        return Stack(alignment: Alignment.topRight, children: [
          Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.black87, size: 24), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationPage(userRole: role))))),
          if (hasUnread) Container(margin: const EdgeInsets.all(8), width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
        ]);
      },
    );
  }

  Widget _buildStatCard({required Stream<QuerySnapshot> stream, required IconData icon, required String label, required Color color, required int Function(List<QueryDocumentSnapshot>) calcLogic, required VoidCallback onTap}) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          int count = 0;
          if (snapshot.hasData) count = calcLogic(snapshot.data!.docs);
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 140,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 24, color: color)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("$count Items", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                ])
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: Colors.white, size: 28)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))])), const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16)])));
  }

  Widget _buildActivityItem({required String title, required String subtitle, required String trailingText, required Color trailingColor, required IconData icon}) {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: trailingColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: trailingColor, size: 20)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600))])), Text(trailingText, style: TextStyle(color: trailingColor, fontWeight: FontWeight.w900, fontSize: 15))]));
  }

  // --- ADD THIS HELPER METHOD ---
  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanAndShowDetails() async {
    final scanned = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));

    if (scanned != null) {
      var snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('barcodeNo', isEqualTo: scanned)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        int? num = int.tryParse(scanned);
        if (num != null) {
          snapshot = await FirebaseFirestore.instance
              .collection('products')
              .where('barcodeNo', isEqualTo: num)
              .limit(1)
              .get();
        }
      }

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final String imageUrl = data['imageUrl'] ?? "";

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: const EdgeInsets.only(bottom: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Dialog size adjusts to content
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),

                // --- UPDATED IMAGE SECTION ---
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4, // Limits max height to 40% of screen
                    minWidth: double.infinity,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain, // Shows full image without cropping
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey),
                      )
                          : Container(
                        height: 150,
                        color: Colors.grey[100],
                        child: const Icon(Icons.inventory_2_rounded, size: 60, color: Colors.grey),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        data['productName'] ?? 'Unknown Product',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Barcode: ${data['barcodeNo']}",
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDetailChip(Icons.storage_rounded, "${data['currentStock']} left", Colors.blue),
                          const SizedBox(width: 12),
                          _buildDetailChip(Icons.payments_rounded, "RM ${data['price']}", Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF203288),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }
}