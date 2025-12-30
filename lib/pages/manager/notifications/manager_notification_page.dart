import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'expiry_alert_detail_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  String? selectedCategory;

  // 🔹 Track read notifications
  final Set<String> readNotifications = {};

  // 🔹 Cache for batch docs
  List<QueryDocumentSnapshot>? _batchDocs;

  // 🔹 Track notification stage for sticky behavior
  final Map<String, String> _notificationStage = {}; // batchId -> "5", "3", "expired"

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
            case 0:
              headerText = "All Alerts";
              break;
            case 1:
              headerText = "Unread Alerts";
              break;
            case 2:
              headerText = "Expiry Alerts";
              break;
            case 3:
              headerText = "Risk Alerts";
              break;
          }
        });
      }
    });
  }



  // ================= FILTER =================
  void _showFilterDialog() async {
    // Get all subCategories from Firebase dynamically
    final productSnapshot =
    await FirebaseFirestore.instance.collection('products').get();

    final allSubCategories = productSnapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['subCategory'] as String)
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
                            tempSelected = [subCat]; // ONLY ONE allowed
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
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedSubCategories = List.from(tempSelected);
                  });
                  Navigator.pop(context);
                },
                child: const Text("Apply")),
          ],
        );
      },
    );
  }



// ================= EXPIRY NOTIFICATION =================
  Widget _buildExpiryNotificationList({bool unreadOnly = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('notifiedAt', descending: true)
          .snapshots(),
      builder: (context, alertSnap) {
        if (!alertSnap.hasData) return const Center(child: CircularProgressIndicator());

        // Filter alerts
        final alerts = alertSnap.data!.docs.where((doc) {
          final alert = doc.data() as Map<String, dynamic>;
          final alertId = doc.id;

          // Only show isDone = false for unread tab
          if (unreadOnly) {
            return !alert['isDone'] && !readNotifications.contains(alertId);
          }

          return true; // For other tabs, show all
        }).toList();

        if (alerts.isEmpty) {
          return Center(
              child: Text(
                  unreadOnly ? "No unread alerts yet" : "No expiry notifications"));
        }

        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

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
                final productSubCat = product['subCategory'] as String;

                // 🔹 ADD THIS FILTER LOGIC HERE
                // If a filter is selected, check if this product matches it.
                // If it doesn't match, return an empty box (effectively hiding it).
                if (selectedSubCategories.isNotEmpty &&
                    !selectedSubCategories.contains(productSubCat)) {
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
                        setState(() {
                          readNotifications.add(alertId);
                        });

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
                          color: isDone
                              ? Colors.grey[100]
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isDone
                                  ? Colors.grey.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // LEFT BLUE LINE FOR UNREAD
                            Container(
                              width: 5,
                              height: 130,
                              decoration: BoxDecoration(
                                color: isDone ? Colors.transparent : const Color(0xFF1E3A8A),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
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
                                        Text(
                                          "🔔 $statusText",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                        Text(
                                          "${todayDate.day.toString().padLeft(2, '0')}.${todayDate.month.toString().padLeft(2, '0')}.${todayDate.year}",
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      product['productName'],
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Sub Category: ${product['subCategory']}",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      "Batch No: ${batch['batchNumber']}",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      "Expiry Date: ${expiryDate.day.toString().padLeft(2, '0')}.${expiryDate.month.toString().padLeft(2, '0')}.${expiryDate.year}",
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red),
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

  // ================= MAIN UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications",
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
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
          // ---------------- FILTER & SEARCH ROW ----------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // LEFT: current tab title
                Text(
                  headerText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // RIGHT: filter & search icons
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Color(0xFF233E99)),
                      onPressed: _showFilterDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ---------------- TABBARVIEW ----------------
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
