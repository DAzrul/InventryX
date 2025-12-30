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

    // Auto-create alerts for existing batches
    _createExpiryAlertForAllBatches();

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

  Future<void> _sendPushNotificationOnce(String alertId, String productName, String stage) async {
    final alertRef = FirebaseFirestore.instance.collection('alerts').doc(alertId);
    final alertSnap = await alertRef.get();
    final alertData = alertSnap.data() as Map<String, dynamic>;

    // Only send if not already notified
    if (alertData['isNotified'] == false) {
      // Get FCM token (optional for testing)
      String? token = await FirebaseMessaging.instance.getToken();
      print("FCM Token: $token");

      // Show SnackBar for testing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Push Notification: $productName expires in $stage days"),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Update Firestore so it won't notify again
      await alertRef.update({'isNotified': true});
    }
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

  // ================= EXPIRY ALERT CREATION =================
  Future<void> _createExpiryAlertForAllBatches() async {
    final alertsRef = FirebaseFirestore.instance.collection('alerts');
    final batchesRef = FirebaseFirestore.instance.collection('batches');

    // 1. Get all batches from the database
    final batchSnapshot = await batchesRef.get();

    for (var batchDoc in batchSnapshot.docs) {
      final batch = batchDoc.data() as Map<String, dynamic>;
      final batchId = batchDoc.id;
      final batchNumber = batch['batchNumber'] ?? '';

      // Convert Firestore Timestamp to DateTime
      final expiryRaw = (batch['expiryDate'] as Timestamp).toDate();
      final today = DateTime.now();

      // 2. Normalize dates to ignore time (HH:mm:ss) for accurate day calculation
      final expiryDate = DateTime(expiryRaw.year, expiryRaw.month, expiryRaw.day);
      final todayDate = DateTime(today.year, today.month, today.day);

      final daysLeft = expiryDate.difference(todayDate).inDays;


      // 3. Determine if the batch hits a specific notification stage
      String? stage;
      if (daysLeft == 0) {
        stage = "expired";
      } else if (daysLeft == 3) {
        stage = "3";
      } else if (daysLeft == 5) {
        stage = "5";
      }
      if (stage == null) continue;

      // 4. Check if we have ALREADY created an alert for THIS batch at THIS stage
      // This prevents duplicate pushes for the same 5-day or 3-day window.
      final existing = await alertsRef
          .where('batchId', isEqualTo: batchId)
          .where('expiryStage', isEqualTo: stage)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        // Fetch product info to include in the alert document
        final productId = batch['productId'] ?? '';
        final productSnap = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get();

        if (!productSnap.exists) continue;

        final product = productSnap.data() as Map<String, dynamic>;
        final productName = product['productName'] ?? 'Unknown Product';

        // 5. Create the alert document.
        // This addition will trigger your Cloud Function (index.js) via onDocumentCreated.
        await alertsRef.add({
          'alertType': 'expiry',
          'expiryStage': stage, // "5", "3", or "expired"
          'batchId': batchId,
          'productId': productId,
          'productName': productName,
          'batchNumber': batchNumber,
          'isRead': false,
          'isDone': false,
          'isNotified': false, // Used for local snackbar tracking
          'notifiedAt': FieldValue.serverTimestamp(),
        });

        print("New alert document generated for $productName (Stage: $stage)");
      } else {
        // Alert already exists for this stage, so we do nothing.
        // This prevents multiple push notifications for the same stage.
        print("Alert for $batchId at stage $stage already exists. Skipping.");
      }
    }
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

                    _sendPushNotificationOnce(alertId, product['productName'], stage);

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
