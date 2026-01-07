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

  // Warna Tema
  final Color primaryColor = const Color(0xFF233E99);
  final Color infoColor = const Color(0xFF1E3A8A);

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

  // 🔹 Tab Helper dengan Red Dot
  Widget _buildTabWithRedDot(String label, {String? filterType}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
      builder: (context, snapshot) {
        bool hasUnread = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          hasUnread = snapshot.data!.docs.any((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final bool isDone = data['isDone'] ?? false;
            final String type = data['alertType'] ?? '';
            final String id = doc.id;

            bool unread = (isDone == false) && !readNotifications.contains(id);

            if (filterType == null) {
              return unread;
            } else {
              return unread && type == filterType;
            }
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
  }

  // ================= FILTER DIALOG =================
  void _showFilterDialog() async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));

    final productSnapshot = await FirebaseFirestore.instance.collection('products').get();

    if (mounted) Navigator.pop(context);

    final allSubCategories = productSnapshot.docs
        .map((doc) => (doc.data())['subCategory'] as String)
        .toSet()
        .toList();

    List<String> tempSelected = List.from(selectedSubCategories);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Filter by Category", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: allSubCategories.isEmpty
                ? const Text("No categories found.")
                : ListView(
              shrinkWrap: true,
              children: allSubCategories.map((subCat) {
                return StatefulBuilder(
                    builder: (context, setStateDialog) {
                      return CheckboxListTile(
                        activeColor: primaryColor,
                        title: Text(subCat),
                        value: tempSelected.contains(subCat),
                        onChanged: (value) {
                          setStateDialog(() {
                            if (value == true) {
                              tempSelected = [subCat];
                            } else {
                              tempSelected.remove(subCat);
                            }
                          });
                        },
                      );
                    }
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
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
        if (alertSnap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        if (!alertSnap.hasData || alertSnap.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final alerts = alertSnap.data!.docs.where((doc) {
          final alert = doc.data() as Map<String, dynamic>;
          final type = alert['alertType'] ?? 'expiry';
          final bool isDoneInDb = alert['isDone'] ?? false;

          if (unreadOnly) {
            bool isUnread = isDoneInDb == false && !readNotifications.contains(doc.id);
            if (!isUnread) return false;
          }

          if (filterType != null && type != filterType) return false;

          return true;
        }).toList();

        if (alerts.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: alerts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            "No alerts found",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ================= CARD BUILDERS =================
  Widget _buildExpiryCard(Map<String, dynamic> alert, String alertId) {
    final String batchId = alert['batchId'] ?? '';
    final String productId = alert['productId'] ?? '';
    final String stage = alert['expiryStage']?.toString() ?? '0';
    final bool isDone = alert['isDone'] ?? false;
    final DateTime notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    Color statusColor;
    Color statusBgColor;
    String statusText;

    switch (stage) {
      case "expired":
        statusText = "EXPIRED";
        statusColor = const Color(0xFFB91C1C);
        statusBgColor = const Color(0xFFFEE2E2);
        break;
      case "3":
        statusText = "Expiring in 3 Days";
        statusColor = const Color(0xFFC2410C);
        statusBgColor = const Color(0xFFFFEDD5);
        break;
      case "5":
        statusText = "Expiring in 5 Days";
        statusColor = const Color(0xFFA16207);
        statusBgColor = const Color(0xFFFEF9C3);
        break;
      default:
        statusText = "Expiring in $stage Days";
        statusColor = const Color(0xFF1D4ED8);
        statusBgColor = const Color(0xFFDBEAFE);
    }

    if (productId.isEmpty) return const SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
      builder: (context, productSnap) {
        if (!productSnap.hasData) return const SizedBox();
        if (!productSnap.data!.exists) return const SizedBox();

        final product = productSnap.data!.data() as Map<String, dynamic>;

        if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(product['subCategory'])) {
          return const SizedBox.shrink();
        }

        final String category = product['category'] ?? "N/A";
        final String subCategory = product['subCategory'] ?? "N/A";
        final String productName = product['productName'] ?? 'Unknown Product';

        if (batchId.isEmpty) {
          return _cardWrapper(
              alertId: alertId,
              isDone: isDone,
              accentColor: Colors.grey,
              onTap: (){},
              child: Text("Error: Batch ID missing for $productName")
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('batches').doc(batchId).get(),
          builder: (context, batchSnap) {
            String batchNumber = "Loading...";
            DateTime expiryDate = DateTime.now();

            if (batchSnap.hasData && batchSnap.data!.exists) {
              final batch = batchSnap.data!.data() as Map<String, dynamic>;
              batchNumber = batch['batchNumber'] ?? "Unknown";
              expiryDate = (batch['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now();
            } else if (batchSnap.connectionState == ConnectionState.done && !batchSnap.hasData) {
              batchNumber = "Batch Not Found";
            }

            return _cardWrapper(
              alertId: alertId,
              isDone: isDone,
              accentColor: infoColor,
              onTap: () {
                if (batchId.isNotEmpty && productId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpiryAlertDetailPage(
                        batchId: batchId,
                        productId: productId,
                        stage: stage,
                        userRole: widget.userRole,
                      ),
                    ),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ROW (Anti-Overflow) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Guna Expanded supaya badge tidak menolak tarikh keluar skrin
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStatusBadge(statusText, statusColor, statusBgColor, Icons.timer_outlined),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${notifiedAt.day}/${notifiedAt.month}/${notifiedAt.year}",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- PRODUCT NAME (Multi-line) ---
                  Text(
                    productName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                    maxLines: 2, // Limit baris
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // --- CATEGORY ROW (Anti-Overflow) ---
                  Row(
                    children: [
                      Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "$subCategory • $category",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 12, thickness: 0.5),

                  // --- FOOTER ROW (Batch & Exp Anti-Overflow) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Batch: $batchNumber",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Exp: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent),
                      ),
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
    final riskLevel = alert['riskLevel'] ?? 'Medium';
    final riskValue = alert['riskValue'] ?? 0;
    final productName = alert['productName'] ?? 'Unknown Product';
    final riskAnalysisId = alert['riskAnalysisId'] ?? '';
    final notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    Color riskColor = riskLevel == "High" ? const Color(0xFFB91C1C) : const Color(0xFFC2410C);
    Color riskBgColor = riskLevel == "High" ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDD5);
    IconData riskIcon = riskLevel == "High" ? Icons.local_fire_department : Icons.warning_amber_rounded;

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('products').get(),
      builder: (context, productSnap) {
        String category = "N/A";
        String subCategory = "N/A";

        if (productSnap.hasData && productSnap.data!.docs.isNotEmpty) {
          try {
            final matchingDoc = productSnap.data!.docs.firstWhere(
                    (doc) => (doc.data() as Map<String, dynamic>)['productName'] == productName,
                orElse: () => productSnap.data!.docs.first
            );

            if ((matchingDoc.data() as Map<String, dynamic>)['productName'] == productName) {
              final productData = matchingDoc.data() as Map<String, dynamic>;
              category = productData['category'] ?? "N/A";
              subCategory = productData['subCategory'] ?? "N/A";

              if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(subCategory)) {
                return const SizedBox.shrink();
              }
            }
          } catch (e) {
            // Ignore error
          }
        }

        return _cardWrapper(
          alertId: alertId,
          isDone: isDone,
          accentColor: riskColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RiskAlertDetailPage(
                  riskAnalysisId: riskAnalysisId,
                  alertId: alertId,
                  userRole: widget.userRole,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ROW (Anti-Overflow) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildStatusBadge("${riskLevel.toUpperCase()} RISK", riskColor, riskBgColor, riskIcon),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${notifiedAt.day}/${notifiedAt.month}/${notifiedAt.year}",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // --- PRODUCT NAME (Multi-line) ---
              Text(
                productName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // --- CATEGORY ROW (Anti-Overflow) ---
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "$subCategory ($category)",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Risk Score", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("$riskValue/100", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: riskColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (riskValue is int ? riskValue.toDouble() : (riskValue as double)) / 100,
                    backgroundColor: Colors.grey.shade200,
                    color: riskColor,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // 🔹 Helper Widget untuk Status Badge (Anti-Overflow)
  Widget _buildStatusBadge(String text, Color textColor, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          // Guna Flexible supaya teks boleh potong jika terlalu panjang
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ================= CARD WRAPPER =================
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFF8F9FA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isDone ? Border.all(color: Colors.grey.shade200) : null,
          boxShadow: [
            if (!isDone)
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔹 Bar Indikator Status (Kiri)
              if (!isDone)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),

              // 🔹 Konten Utama
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: child,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            const Tab(text: "All"),
            _buildTabWithRedDot("Unread"),
            _buildTabWithRedDot("Expiry", filterType: 'expiry'),
            _buildTabWithRedDot("Risk", filterType: 'risk'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header & Filter Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  headerText,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                ),
                GestureDetector(
                  onTap: _showFilterDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.filter_list_rounded, color: primaryColor, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
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