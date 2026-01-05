import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'expiry_alert_detail_page.dart';
import 'risk_alert_detail_page.dart';

class NotificationPage extends StatefulWidget {
  final String userRole;

  const NotificationPage({super.key, required this.userRole});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String headerText = "All Alerts";

  final Set<String> readNotifications = {};
  List<String> selectedSubCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0: headerText = "All Alerts"; break;
            case 1: headerText = "Unread Alerts"; break;
            case 2: headerText = "Expiry Alerts"; break;
            case 3: headerText = "Risk Alerts"; break;
          }
        });
      }
    });
  }

  // 🔹 FIXED HELPER: Builds a Tab with a Red Dot using Client-Side filtering
  Widget _buildTabWithRedDot(String label, {String? filterType}) {
    return StreamBuilder<QuerySnapshot>(
      // 🔹 Fetch all alerts to filter manually (Bypasses indexing error)
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .snapshots(),
      builder: (context, snapshot) {
        bool hasUnread = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          // Manually check for unread alerts in the results
          hasUnread = snapshot.data!.docs.any((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final bool isDone = data['isDone'] ?? false;
            final String type = data['alertType'] ?? '';
            final String id = doc.id;

            // Condition: Not marked as done in DB AND not clicked in this session
            bool unread = (isDone == false) && !readNotifications.contains(id);

            if (filterType == null) {
              return unread; // For "Unread" tab
            } else {
              return unread && type == filterType; // For "Expiry" or "Risk" tabs
            }
          });
        }

        return Tab(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(label),
              if (hasUnread)
                Positioned(
                  right: -10, // Adjust position so it doesn't overlap text
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ================= FILTER DIALOG =================
  void _showFilterDialog() async {
    final productSnapshot = await FirebaseFirestore.instance.collection('products').get();
    final allSubCategories = productSnapshot.docs
        .map((doc) => (doc.data())['subCategory'] as String)
        .toSet()
        .toList();

    List<String> tempSelected = List.from(selectedSubCategories);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Filter by Sub Category"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: allSubCategories.map((subCat) {
                    return CheckboxListTile(
                      title: Text(subCat),
                      value: tempSelected.contains(subCat),
                      onChanged: (value) {
                        setStateDialog(() {
                          if (value == true) {
                            tempSelected = [subCat];
                          } else {
                            tempSelected.clear();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                setState(() { selectedSubCategories = List.from(tempSelected); });
                Navigator.pop(context);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  // ================= NOTIFICATION LIST BUILDER =================
  Widget _buildNotificationList({bool unreadOnly = false, String? filterType}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('notifiedAt', descending: true)
          .snapshots(),
      builder: (context, alertSnap) {
        if (!alertSnap.hasData) return const Center(child: CircularProgressIndicator());

        final alerts = alertSnap.data!.docs.where((doc) {
          final alert = doc.data() as Map<String, dynamic>;
          final type = alert['alertType'] ?? 'expiry';
          final bool isDoneInDb = alert['isDone'] ?? false; // 🔹 Current DB status

          // 1. If we are in the "Unread" tab (unreadOnly = true)
          if (unreadOnly) {
            // Only show if it's NOT done in DB AND hasn't been clicked in this session
            bool isUnread = isDoneInDb == false && !readNotifications.contains(doc.id);
            if (!isUnread) return false;
          }

          // 2. Filter by alert type if specific tab is selected (Expiry or Risk)
          if (filterType != null && type != filterType) return false;

          return true;
        }).toList();

        if (alerts.isEmpty) {
          return Center(
            child: Text(
              unreadOnly ? "No unread alerts" : "No notifications",
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alertDoc = alerts[index];
            final alert = alertDoc.data() as Map<String, dynamic>;
            final type = alert['alertType'] ?? 'expiry';

            return type == 'risk'
                ? _buildRiskCard(alert, alertDoc.id)
                : _buildExpiryCard(alert, alertDoc.id);
          },
        );
      },
    );
  }

// ================= CARD BUILDERS =================
  Widget _buildExpiryCard(Map<String, dynamic> alert, String alertId) {
    final batchId = alert['batchId'];
    final productId = alert['productId'];
    final stage = alert['expiryStage'];
    final isDone = alert['isDone'] ?? false;
    final notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // 1. DYNAMIC COLOR LOGIC
    Color statusColor;
    String statusText;

    switch (stage) {
      case "expired":
        statusText = "EXPIRED";
        statusColor = Colors.red;
        break;
      case "3":
        statusText = "EXPIRY SOON (3 Days)";
        statusColor = Colors.yellow[900]!;
        break;
      case "5":
        statusText = "EXPIRY SOON (5 Days)";
        statusColor = Colors.yellow[600]!;
        break;
      default:
        statusText = "EXPIRY SOON ($stage Days)";
        statusColor = Colors.orange; // Fallback color
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
      builder: (context, productSnap) {
        if (!productSnap.hasData) return const SizedBox();
        final product = productSnap.data!.data() as Map<String, dynamic>;

        if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(product['subCategory'])) {
          return const SizedBox.shrink();
        }

        // Extract Category and SubCategory
        final String category = product['category'] ?? "N/A";
        final String subCategory = product['subCategory'] ?? "N/A";

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('batches').doc(batchId).get(),
          builder: (context, batchSnap) {
            if (!batchSnap.hasData) return const SizedBox();
            final batch = batchSnap.data!.data() as Map<String, dynamic>;
            final expiryDate = (batch['expiryDate'] as Timestamp).toDate();

            return _cardWrapper(
              alertId: alertId,
              isDone: isDone,
              accentColor: const Color(0xFF1E3A8A),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpiryAlertDetailPage(
                    batchId: batchId,
                    productId: productId,
                    stage: stage,
                    userRole: widget.userRole,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("🔔 $statusText",
                          style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                      Text("${notifiedAt.day}/${notifiedAt.month}/${notifiedAt.year}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(product['productName'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),

                  // 2. ADDED SUBCATEGORY (CATEGORY) TEXT
                  Text(
                    "$subCategory ($category)",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),

                  const SizedBox(height: 4),
                  Text("Batch No: ${batch['batchNumber']}", style: const TextStyle(fontSize: 14)),
                  Text(
                    "Expiry Date: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
                  ),
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
    final riskLevel = alert['riskLevel'] ?? 'Medium';
    final riskValue = alert['riskValue'] ?? 0;
    final productName = alert['productName'] ?? 'Unknown';
    final riskAnalysisId = alert['riskAnalysisId'] ?? '';
    final notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    Color riskColor = riskLevel == "High" ? Colors.red : Colors.orange;
    String riskIcon = riskLevel == "High" ? "🔥" : "⚠️";
    String riskTitle = "$riskIcon ${riskLevel.toUpperCase()} RISK";

    return FutureBuilder<QuerySnapshot>(
      // 🔹 Fetch products to filter manually (Bypasses indexing error)
      future: FirebaseFirestore.instance.collection('products').get(),
      builder: (context, productSnap) {
        String category = "N/A";
        String subCategory = "N/A";

        if (productSnap.hasData && productSnap.data!.docs.isNotEmpty) {
          try {
            // 🔹 Manually find the product that matches the name from the alert
            final matchingDoc = productSnap.data!.docs.firstWhere(
                    (doc) => (doc.data() as Map<String, dynamic>)['productName'] == productName
            );

            final productData = matchingDoc.data() as Map<String, dynamic>;
            category = productData['category'] ?? "N/A";
            subCategory = productData['subCategory'] ?? "N/A";

            // Apply subCategory filter if active
            if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(subCategory)) {
              return const SizedBox.shrink();
            }
          } catch (e) {
            // No matching product name found in the products collection
          }
        }

        return _cardWrapper(
          alertId: alertId,
          isDone: isDone,
          accentColor: riskColor,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    riskTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, color: riskColor, fontSize: 13),
                  ),
                  Text(
                    "${notifiedAt.day}/${notifiedAt.month}/${notifiedAt.year}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                productName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),

              // 🔹 Display Category and SubCategory retrieved from products collection
              Text(
                "$subCategory ($category)",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500
                ),
              ),

              const SizedBox(height: 4),
              Text(
                "Risk Score: $riskValue/100",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= CARD WRAPPER (Indicator Logic) =================
  Widget _cardWrapper({
    required String alertId,
    required bool isDone,
    required Color accentColor,
    required VoidCallback onTap,
    required Widget child
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => readNotifications.add(alertId));
        onTap();
      },
      child: IntrinsicHeight( // 🔹 Ensures the Row children can match height
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFFFAFAFA) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: isDone ? Colors.black.withOpacity(0.02) : accentColor.withOpacity(0.12),
                  blurRadius: isDone ? 4 : 8,
                  offset: const Offset(0, 4)
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, // 🔹 Forces line to stretch top-to-bottom
            children: [
              // 🔹 Blue vertical line
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isDone ? 0 : 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12)
                  ),
                ),
              ),
              // 🔹 Content area
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: child
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: const Color(0xFF233E99),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF233E99),
          tabs: [
            const Tab(text: "All Alerts"), // "All" usually doesn't need a dot
            _buildTabWithRedDot("Unread"),
            _buildTabWithRedDot("Expiry", filterType: 'expiry'),
            _buildTabWithRedDot("Risk", filterType: 'risk'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(headerText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.filter_list, color: Color(0xFF233E99)), onPressed: _showFilterDialog),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList(),
                _buildNotificationList(unreadOnly: true),
                _buildNotificationList(filterType: 'expiry'),
                _buildNotificationList(filterType: 'risk'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}