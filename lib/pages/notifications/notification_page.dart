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

  // Warna Konsisten
  final Color primaryBlue = const Color(0xFF203288);
  final Color accentBlue = const Color(0xFF1E3A8A);

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

  // ================= FILTER DIALOG =================
  void _showFilterDialog() async {
    final productSnapshot = await FirebaseFirestore.instance.collection('products').get();
    final allSubCategories = productSnapshot.docs
        .map((doc) => (doc.data())['subCategory'] as String?)
        .where((s) => s != null && s.isNotEmpty)
        .toSet()
        .toList();

    List<String> tempSelected = List.from(selectedSubCategories);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Filter by Sub Category", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: allSubCategories.map((subCat) {
                return StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return CheckboxListTile(
                      activeColor: primaryBlue,
                      title: Text(subCat!),
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
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() { selectedSubCategories = List.from(tempSelected); });
                Navigator.pop(context);
              },
              child: const Text("Apply", style: TextStyle(color: Colors.white)),
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

          if (filterType != null && type != filterType) return false;

          if (unreadOnly) {
            return (alert['isDone'] == false) && !readNotifications.contains(doc.id);
          }
          return true;
        }).toList();

        if (alerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text(
                  unreadOnly ? "No unread alerts" : "No notifications",
                  style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
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

  // 1. EXPIRY CARD
  Widget _buildExpiryCard(Map<String, dynamic> alert, String alertId) {
    final batchId = alert['batchId'];
    final productId = alert['productId'];
    final stage = alert['expiryStage'];
    final isDone = alert['isDone'] ?? false;
    final notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

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
        statusColor = Colors.orange;
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
      builder: (context, productSnap) {
        if (!productSnap.hasData) return const SizedBox();
        final product = productSnap.data!.data() as Map<String, dynamic>? ?? {};

        if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(product['subCategory'])) {
          return const SizedBox.shrink();
        }

        final String category = product['category'] ?? "N/A";
        final String subCategory = product['subCategory'] ?? "N/A";

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('batches').doc(batchId).get(),
          builder: (context, batchSnap) {
            if (!batchSnap.hasData) return const SizedBox();
            final batch = batchSnap.data!.data() as Map<String, dynamic>? ?? {};
            final expiryDate = (batch['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now();

            return _cardWrapper(
              alertId: alertId,
              isDone: isDone,
              accentColor: accentBlue,
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
              child: _buildStandardCardContent(
                statusText: statusText,
                statusColor: statusColor,
                notifiedAt: notifiedAt,
                productName: product['productName'] ?? 'Unknown Product',
                categoryText: "$subCategory • $category",
                footerWidgets: [
                  _buildFooterItem("Batch", batch['batchNumber'] ?? '-'),
                  _buildFooterItem(
                    "Expiry",
                    "${expiryDate.day}/${expiryDate.month}/${expiryDate.year}",
                    valueColor: Colors.red,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 2. RISK CARD (FIX: CARI GUNA NAMA PRODUK)
  Widget _buildRiskCard(Map<String, dynamic> alert, String alertId) {
    final isDone = alert['isDone'] ?? false;
    final riskLevel = alert['riskLevel'] ?? 'Medium';
    final riskValue = alert['riskValue'] ?? 0;
    final riskAnalysisId = alert['riskAnalysisId'] ?? '';
    final notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Ambil nama produk dari alert (Risk Alert biasanya ada simpan nama)
    final alertProductName = alert['productName'] ?? 'Unknown Product';

    Color riskColor = riskLevel == "High" ? Colors.red : Colors.orange;
    String riskIcon = riskLevel == "High" ? "🔥" : "⚠️";
    String riskTitle = "$riskIcon ${riskLevel.toUpperCase()} RISK";

    // [FIX UTAMA]: Guna Query 'where' berdasarkan Nama Produk, bukan 'doc(id)'
    // Sebab ID dalam Risk mungkin tak sama dengan ID Produk
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('products')
          .where('productName', isEqualTo: alertProductName)
          .limit(1)
          .get(),
      builder: (context, productSnap) {
        String category = "N/A";
        String subCategory = "N/A";

        // Cek jika jumpa produk dengan nama yang sama
        if (productSnap.hasData && productSnap.data!.docs.isNotEmpty) {
          final product = productSnap.data!.docs.first.data() as Map<String, dynamic>;
          category = product['category'] ?? "N/A";
          subCategory = product['subCategory'] ?? "N/A";

          if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(subCategory)) {
            return const SizedBox.shrink();
          }
        }

        // Kalau category masih N/A, sembunyikan baris kategori atau letak text default
        String displayCategoryText = (subCategory == "N/A" && category == "N/A")
            ? "Inventory Risk"
            : "$subCategory • $category";

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
          child: _buildStandardCardContent(
            statusText: riskTitle,
            statusColor: riskColor,
            notifiedAt: notifiedAt,
            productName: alertProductName, // Guna nama dari alert
            categoryText: displayCategoryText, // Guna text yang dah diproses
            footerWidgets: [
              _buildFooterItem(
                "Risk Score",
                "$riskValue/100",
                valueColor: riskColor,
                isBold: true,
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= UNIFIED UI HELPERS =================

  Widget _buildStandardCardContent({
    required String statusText,
    required Color statusColor,
    required DateTime notifiedAt,
    required String productName,
    required String categoryText,
    required List<Widget> footerWidgets,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              statusText,
              style: TextStyle(fontWeight: FontWeight.w800, color: statusColor, fontSize: 12, letterSpacing: 0.5),
            ),
            Text(
              "${notifiedAt.day}/${notifiedAt.month}/${notifiedAt.year}",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          productName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          categoryText,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 0.5),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: footerWidgets.map((w) {
            return Padding(
              padding: const EdgeInsets.only(right: 20),
              child: w,
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _buildFooterItem(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor ?? Colors.black87,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _cardWrapper({
    required String alertId,
    required bool isDone,
    required Color accentColor,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => readNotifications.add(alertId));
        onTap();
      },
      child: IntrinsicHeight(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFFFAFAFA) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDone ? 0.02 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: isDone ? Colors.grey.shade300 : accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
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
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 3,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          indicatorColor: primaryBlue,
          tabs: const [
            Tab(text: "All"),
            Tab(text: "Unread"),
            Tab(text: "Expiry"),
            Tab(text: "Risk"),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 15, 10, 5),
            color: const Color(0xFFF8FAFF),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(headerText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                    child: Icon(Icons.filter_list_rounded, color: primaryBlue, size: 20),
                  ),
                  onPressed: _showFilterDialog,
                ),
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