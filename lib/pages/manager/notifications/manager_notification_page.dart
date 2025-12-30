import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'expiry_alert_detail_page.dart';

class ManagerNotificationPage extends StatefulWidget {
  const ManagerNotificationPage({super.key});

  @override
  State<ManagerNotificationPage> createState() =>
      _ManagerNotificationPageState();
}

class _ManagerNotificationPageState extends State<ManagerNotificationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String headerText = "All Alerts";

  // 🔹 Track read notifications locally for immediate UI feedback
  final Set<String> readNotifications = {};

  // 🔹 Selected subCategories for filter
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
                            tempSelected = [subCat]; // Single Select
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
  Widget _buildExpiryNotificationList({bool unreadOnly = false}) {
    return StreamBuilder<QuerySnapshot>(
      // Listening directly to 'alerts' populated by index.js
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('notifiedAt', descending: true)
          .snapshots(),
      builder: (context, alertSnap) {
        if (!alertSnap.hasData) return const Center(child: CircularProgressIndicator());

        final alerts = alertSnap.data!.docs.where((doc) {
          final alert = doc.data() as Map<String, dynamic>;
          final alertId = doc.id;

          if (unreadOnly) {
            // Check Firestore status AND local session set
            return (alert['isDone'] == false) && !readNotifications.contains(alertId);
          }
          return true;
        }).toList();

        if (alerts.isEmpty) {
          return Center(child: Text(unreadOnly ? "No unread alerts yet" : "No notifications"));
        }

        return ListView.builder(
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alertDoc = alerts[index];
            final alert = alertDoc.data() as Map<String, dynamic>;
            final alertId = alertDoc.id;

            final batchId = alert['batchId'];
            final productId = alert['productId'];
            final stage = alert['expiryStage'];
            final isDone = alert['isDone'] ?? false;
            final notifiedAt = (alert['notifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            // Status Styling logic
            String statusText = "";
            Color statusColor = Colors.black;
            if (stage == "expired") {
              statusText = "EXPIRED";
              statusColor = Colors.red;
            } else if (stage == "3") {
              statusText = "EXPIRY SOON (3 Days)";
              statusColor = Colors.yellow[900]!;
            } else if (stage == "5") {
              statusText = "EXPIRY SOON (5 Days)";
              statusColor = Colors.yellow[600]!;
            }

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
              builder: (context, productSnap) {
                if (!productSnap.hasData) return const SizedBox();
                final product = productSnap.data!.data() as Map<String, dynamic>;

                // 🔹 Apply Sub-Category Filter
                if (selectedSubCategories.isNotEmpty && !selectedSubCategories.contains(product['subCategory'])) {
                  return const SizedBox.shrink();
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('batches').doc(batchId).get(),
                  builder: (context, batchSnap) {
                    if (!batchSnap.hasData) return const SizedBox();
                    final batch = batchSnap.data!.data() as Map<String, dynamic>;
                    final expiryDate = (batch['expiryDate'] as Timestamp).toDate();

                    return GestureDetector(
                      onTap: () {
                        setState(() { readNotifications.add(alertId); });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExpiryAlertDetailPage(
                              batchId: batchId,
                              productId: productId,
                              stage: stage,
                            ),
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDone ? Colors.grey[100] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isDone ? Colors.grey.withOpacity(0.1) : Colors.blue.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 130,
                              decoration: BoxDecoration(
                                color: isDone ? Colors.transparent : const Color(0xFF1E3A8A),
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("🔔 $statusText", style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                                        Text("${notifiedAt.day}/${notifiedAt.month}/${notifiedAt.year}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(product['productName'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text("Sub Category: ${product['subCategory']}", style: const TextStyle(fontSize: 14)),
                                    Text("Batch No: ${batch['batchNumber']}", style: const TextStyle(fontSize: 14)),
                                    Text(
                                      "Expiry Date: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}",
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF233E99),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF233E99),
          tabs: const [
            Tab(text: "All Alerts"),
            Tab(text: "Unread"),
            Tab(text: "Expiry Alerts"),
            Tab(text: "Risk Alerts"),
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
                _buildExpiryNotificationList(),
                _buildExpiryNotificationList(unreadOnly: true),
                _buildExpiryNotificationList(),
                const Center(child: Text("No risk alerts yet")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}