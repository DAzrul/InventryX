import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'expiry_alert_detail_page.dart';
import 'risk_alert_detail_page.dart';
import 'low_stock_alert_detail_page.dart';

class NotificationPage extends StatefulWidget {
  final String userRole;
  const NotificationPage({super.key, required this.userRole});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String headerText = "All Alerts";
  final Set<String> readNotifications = {};
  List<String> selectedSubCategories = [];

  final Color primaryColor = const Color(0xFF233E99);
  final Color infoColor = const Color(0xFF1E3A8A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0: headerText = "All Alerts"; break;
            case 1: headerText = "Unread Alerts"; break;
            case 2: headerText = "Expiry Alerts"; break;
            case 3: headerText = "Risk Alerts"; break;
            case 4: headerText = "Stock Alerts"; break;
          }
        });
      }
    });
  }

  // --- TAB BUILDER ---
  Widget _buildTabWithRedDot(String label, {String? filterType}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
      builder: (context, alertSnapshot) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('products').get(),
          builder: (context, productSnapshot) {
            bool hasUnread = false;

            if (alertSnapshot.hasData && productSnapshot.hasData) {
              final allProducts = productSnapshot.data!.docs;

              hasUnread = alertSnapshot.data!.docs.any((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final bool isDone = data['isDone'] ?? false;
                final String type = data['alertType'] ?? '';

                // 1. Basic check: Is it undone?
                if (isDone != false) return false;
                // 2. Tab check: Does it match the tab type (Expiry/Risk)?
                if (filterType != null && type != filterType) return false;
                // 3. Filter check: Does it match the selected subCategory?
                if (selectedSubCategories.isNotEmpty) {
                  try {
                    // Find the product linked to this alert
                    final String pId = data['productId'] ?? '';
                    final String pName = data['productName'] ?? '';
                    final productDoc = allProducts.firstWhere((p) {
                      final pData = p.data() as Map<String, dynamic>;
                      return p.id == pId || pData['productName'] == pName;
                    });
                    final String subCat = (productDoc.data() as Map<String, dynamic>)['subCategory'] ?? '';
                    // If the unread item's sub-category is NOT in our filter, don't show the dot
                    if (!selectedSubCategories.contains(subCat)) return false;
                  } catch (e) {
                    return false;
                  }
                }
                return true;
              });
            }
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (hasUnread) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- FILTER DIALOG ---
  void _showFilterDialog() async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
    final productSnapshot = await FirebaseFirestore.instance.collection('products').get();
    if (mounted) Navigator.pop(context);

    final allSubCategories = productSnapshot.docs
        .map((doc) => (doc.data())['subCategory'] as String? ?? "Others")
        .toSet()
        .toList();

    List<String> tempSelected = List.from(selectedSubCategories);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Filter Categories", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: allSubCategories.map((subCat) => StatefulBuilder(
              builder: (context, setStateDialog) => CheckboxListTile(
                activeColor: primaryColor,
                title: Text(subCat, style: const TextStyle(fontSize: 14)),
                value: tempSelected.contains(subCat),
                onChanged: (val) => setStateDialog(() => val == true ? tempSelected.add(subCat) : tempSelected.remove(subCat)),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () { setState(() => selectedSubCategories = List.from(tempSelected)); Navigator.pop(context); },
            child: const Text("Apply", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- CARD COMPONENTS ---
  Widget _buildStatusBadge(String text, Color textColor, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildLowStockCard(Map<String, dynamic> alert, String alertId) {
    final String productId = alert['productId'] ?? '';
    final isDone = alert['isDone'] ?? false;
    final productName = alert['productName'] ?? 'Unknown';
    final currentStock = alert['currentStock'] ?? 0;
    final reorderLevel = alert['reorderLevel'] ?? 0;
    final category = alert['category'] ?? 'N/A';
    final subCategory = alert['subCategory'] ?? 'N/A';
    final notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Stock is low, so we use a Warning color (Orange)
    final Color stockColor = Colors.orange.shade800;

    // Filter check
    if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(subCategory)) {
      return const SizedBox.shrink();
    }

    return _cardWrapper(
      alertId: alertId,
      isDone: isDone,
      accentColor: stockColor,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LowStockAlertDetailPage(
              productId: productId,
              alertId: alertId,
              userRole: widget.userRole,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge("LOW STOCK", stockColor, stockColor.withOpacity(0.1), Icons.trending_down_rounded),
              Text("${notifiedAt.day}/${notifiedAt.month}", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 12), // Increased slightly for better spacing without image

          // 🔹 Product Info (Text only)
          Text(
              productName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  "$subCategory • $category",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Current Stock", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text("$currentStock Units", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: stockColor)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Reorder Level", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text("$reorderLevel Units", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryCard(Map<String, dynamic> alert, String alertId) {
    final String batchId = alert['batchId'] ?? '';
    final String productId = alert['productId'] ?? '';
    final String stage = alert['expiryStage']?.toString() ?? '0';
    final bool isDone = alert['isDone'] ?? false;
    final DateTime notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    Color statusColor = infoColor;
    Color statusBgColor = const Color(0xFFDBEAFE);
    String statusText = "Expiring in $stage Days";

    if (stage == "expired") {
      statusText = "EXPIRED";
      statusColor = Colors.red.shade800;
      statusBgColor = Colors.red.shade50;
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
      builder: (context, productSnap) {
        if (!productSnap.hasData || !productSnap.data!.exists) return const SizedBox.shrink();
        final product = productSnap.data!.data() as Map<String, dynamic>;

        if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(product['subCategory'])) return const SizedBox.shrink();

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('batches').doc(batchId).get(),
          builder: (context, batchSnap) {
            final batch = batchSnap.data?.data() as Map<String, dynamic>?;
            final expiryDate = (batch?['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now();

            return _cardWrapper(
              alertId: alertId, isDone: isDone, accentColor: statusColor,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpiryAlertDetailPage(batchId: batchId, productId: productId, stage: stage, userRole: widget.userRole))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: _buildStatusBadge(statusText, statusColor, statusBgColor, Icons.timer_outlined)),
                      const SizedBox(width: 8),
                      Text("${notifiedAt.day}/${notifiedAt.month}", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(product['productName'] ?? 'Unknown', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text("${product['subCategory']} • ${product['category']}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const Divider(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8, runSpacing: 4,
                    children: [
                      Text("Batch: ${batch?['batchNumber'] ?? '-'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text("Exp: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRiskCard(Map<String, dynamic> alert, String alertId) {
    final isDone = alert['isDone'] ?? false;
    final riskLevel = alert['riskLevel'] ?? 'Med';
    final riskAnalysisId = alert['riskAnalysisId'] ?? '';
    final notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Retrieve product name with fallback for different casing
    final productName = alert['productName'] ?? alert['ProductName'] ?? 'Unknown Product';

    Color rColor = riskLevel == "High" ? Colors.red.shade700 : Colors.orange.shade700;
    Color rBgColor = rColor.withOpacity(0.1);

    return FutureBuilder<QuerySnapshot>(
      // Fetch products to find the one matching the alert's product name
      future: FirebaseFirestore.instance.collection('products').get(),
      builder: (context, productSnap) {
        String category = "N/A";
        String subCategory = "N/A";

        if (productSnap.hasData && productSnap.data!.docs.isNotEmpty) {
          try {
            final matchingDoc = productSnap.data!.docs.firstWhere(
                    (doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['productName'].toString().trim() == productName.toString().trim();
                }
            );

            final productData = matchingDoc.data() as Map<String, dynamic>;
            category = productData['category'] ?? "N/A";
            subCategory = productData['subCategory'] ?? "N/A";

            if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(subCategory)) {
              return const SizedBox.shrink();
            }
          } catch (e) {
            // No matching product found
          }
        }

        return FutureBuilder<DocumentSnapshot>(
          // 🔹 Fetch DaysToExpiry from risk_analysis collection
          future: FirebaseFirestore.instance.collection('risk_analysis').doc(riskAnalysisId).get(),
          builder: (context, riskAnalysisSnap) {
            String daysToExpiryText = "-";
            if (riskAnalysisSnap.hasData && riskAnalysisSnap.data!.exists) {
              final riskData = riskAnalysisSnap.data!.data() as Map<String, dynamic>;
              final days = riskData['DaysToExpiry'];
              daysToExpiryText = (days == null || days == 999) ? "N/A" : "$days";
            }

            return _cardWrapper(
              alertId: alertId,
              isDone: isDone,
              accentColor: rColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RiskAlertDetailPage(
                    riskAnalysisId: riskAnalysisId,
                    alertId: alertId,
                    userRole: widget.userRole,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusBadge("${riskLevel.toUpperCase()} RISK", rColor, rBgColor, Icons.warning_amber),
                      Text(
                        "${notifiedAt.day}/${notifiedAt.month}",
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    productName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  Row(
                    children: [
                      Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "$subCategory • $category",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // 🔹 Added Divider to match Expiry Card style
                  const Divider(height: 16),

                  // 🔹 Added Days to Nearest Expiry display
                  Row(
                    children: [
                      const Text(
                        "Days to Nearest Expiry: ",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        "$daysToExpiryText Days",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent, // Red color as requested
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _cardWrapper({required String alertId, required bool isDone, required Color accentColor, required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: () { setState(() => readNotifications.add(alertId)); onTap(); },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFF8F9FA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [if (!isDone) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isDone) Container(width: 4, decoration: BoxDecoration(color: accentColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
              Expanded(child: Padding(padding: const EdgeInsets.all(12), child: child)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          labelPadding: EdgeInsets.zero,
          labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold
          ),
          tabs: [
            const Tab(text: "All"),
            _buildTabWithRedDot("Unread"),
            _buildTabWithRedDot("Expiry", filterType: 'expiry'),
            _buildTabWithRedDot("Risk", filterType: 'risk'),
            _buildTabWithRedDot("Stock", filterType: 'lowStock'), // UI already had this, but logic needed sync
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(headerText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: _showFilterDialog, icon: const Icon(Icons.filter_list)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(5, (index) { // 🔹 Updated from 4 to 5
                String? type;
                if (index == 2) type = 'expiry';
                if (index == 3) type = 'risk';
                if (index == 4) type = 'lowStock'; // 🔹 Route for the Stock Tab

                return _buildNotificationList(
                  unreadOnly: index == 1,
                  filterType: type,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList({bool unreadOnly = false, String? filterType}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('notifiedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // 1. Unread Filter
          if (unreadOnly && (data['isDone'] == true || readNotifications.contains(doc.id))) {
            return false;
          }

          // 2. Tab Category Filter (expiry, risk, lowStock)
          if (filterType != null && data['alertType'] != filterType) {
            return false;
          }

          return true;
        }).toList();

        if (docs.isEmpty) return const Center(child: Text("No alerts found"));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final String alertType = data['alertType'] ?? '';

            // 🔹 Route to the correct card based on alertType
            if (alertType == 'risk') {
              return _buildRiskCard(data, docs[i].id);
            } else if (alertType == 'lowStock') {
              return _buildLowStockCard(data, docs[i].id);
            } else {
              // Default to Expiry Card
              return _buildExpiryCard(data, docs[i].id);
            }
          },
        );
      },
    );
  }
}