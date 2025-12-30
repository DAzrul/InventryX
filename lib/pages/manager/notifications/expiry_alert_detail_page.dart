import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpiryAlertDetailPage extends StatelessWidget {
  final String batchId;
  final String productId;
  final String stage;

  const ExpiryAlertDetailPage({
    super.key,
    required this.batchId,
    required this.productId,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Expiry Alert",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('batches').doc(batchId).get(),
        builder: (context, batchSnap) {
          if (!batchSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final batch = batchSnap.data!.data() as Map<String, dynamic>;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
            builder: (context, productSnap) {
              if (!productSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final product = productSnap.data!.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('supplier')
                    .doc(product['supplierId'])
                    .get(),
                builder: (context, supplierSnap) {
                  if (!supplierSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final supplier = supplierSnap.data!.data() as Map<String, dynamic>;

                  final expiryRaw = (batch['expiryDate'] as Timestamp).toDate();
                  final createdAt = (batch['createdAt'] as Timestamp).toDate();

                  // Normalize dates (remove time)
                  final today = DateTime.now();
                  final todayDate = DateTime(today.year, today.month, today.day);
                  final expiryDate = DateTime(
                    expiryRaw.year,
                    expiryRaw.month,
                    expiryRaw.day,
                  );

                  final daysLeft = expiryDate.difference(todayDate).inDays;

                  // Determine color and text based on stage
                  Color statusColor;
                  String statusText;

                  if (stage == "expired") {
                    statusText = "EXPIRED";
                    statusColor = Colors.red;
                  } else if (stage == "3") {
                    statusText = "EXPIRY SOON (3 Days)";
                    statusColor = Colors.yellow[900]!;
                  } else if (stage == "5") {
                    statusText = "EXPIRY SOON (5 Days)";
                    statusColor = Colors.yellow[600]!;
                  } else {
                    statusText = "EXPIRY SOON ($stage Days)";
                    statusColor = Colors.orange;
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔔 HEADER
                        Text(
                          "🔔 $statusText",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // PRODUCT DETAILS CONTAINER
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Product Details header
                              const Text(
                                "Product Details",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                              const Divider(thickness: 1.2, height: 20, color: Colors.grey),

                              // Product Image
                              if (product['imageUrl'] != null)
                                Center(
                                  child: Image.network(
                                    product['imageUrl'],
                                    height: 140,
                                  ),
                                ),
                              const SizedBox(height: 12),

                              // Product Name below image
                              Text(
                                product['productName'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),

                              // Information rows
                              _row("Sub Category", product['subCategory']),
                              _row("Supplier Name", supplier['supplierName']),
                              const Divider(thickness: 1.0, color: Colors.grey),
                              _row("Batch Number", batch['batchNumber']),
                              _row("Stock In Date", createdAt.toString().split(' ')[0]),
                              _row("Current Quantity", batch['currentQuantity'].toString()),
                              _row("Expiry Date", expiryDate.toString().split(' ')[0]),
                              _row("Days Left", daysLeft.toString()),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) {
                                  String actionTitle = "";
                                  Color actionColor = Colors.black;
                                  List<Widget> reasonWidgets = [];

                                  if (stage == "5") {
                                    actionTitle = "APPLY DISCOUNT";
                                    actionColor = Colors.yellow[600]!;
                                    reasonWidgets = [
                                      const Text("• Product expires in 5 days"),
                                      const Text("• Suggested Discount Rate: 10–20%"),
                                      RichText(
                                        text: TextSpan(
                                          text: "• Action Urgency: ",
                                          style: const TextStyle(color: Colors.black),
                                          children: [
                                            TextSpan(
                                              text: "MEDIUM",
                                              style: TextStyle(
                                                color: Colors.yellow[600],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ];
                                  } else if (stage == "3") {
                                    actionTitle = "SHELF ROTATION";
                                    actionColor = Colors.yellow[900]!;
                                    reasonWidgets = [
                                      const Text("• Product expires in 3 days"),
                                      const Text("• Move product to front shelf / eye-level"),
                                      RichText(
                                        text: TextSpan(
                                          text: "• Action Urgency: ",
                                          style: const TextStyle(color: Colors.black),
                                          children: [
                                            TextSpan(
                                              text: "HIGH",
                                              style: TextStyle(
                                                color: Colors.yellow[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ];
                                  } else if (stage == "expired") {
                                    actionTitle = "RETURN TO SUPPLIER";
                                    actionColor = Colors.red;
                                    reasonWidgets = [
                                      const Text("• Product has passed expiry date"),
                                      const Text("• Update stock status"),
                                      RichText(
                                        text: const TextSpan(
                                          text: "• Action Urgency: ",
                                          style: TextStyle(color: Colors.black),
                                          children: [
                                            TextSpan(
                                              text: "CRITICAL",
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ];
                                  }

                                  return FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('alerts')
                                        .where('batchId', isEqualTo: batchId)
                                        .where('expiryStage', isEqualTo: stage)
                                        .limit(1)
                                        .get(),
                                    builder: (context, alertSnap) {
                                      if (!alertSnap.hasData) {
                                        return const SizedBox(
                                          height: 200,
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      }

                                      bool isDone = false;
                                      if (alertSnap.data!.docs.isNotEmpty) {
                                        final alertData = alertSnap.data!.docs.first.data() as Map<String, dynamic>;
                                        isDone = alertData['isDone'] ?? false;
                                      }

                                      // Determine buttons
                                      List<Widget> buttons;
                                      if (isDone) {
                                        buttons = [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => Navigator.pop(context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E3A8A),
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text("Close"),
                                            ),
                                          ),
                                        ];
                                      } else {
                                        buttons = [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text("Cancel"),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                // Update alert as done in Firestore
                                                if (alertSnap.data!.docs.isNotEmpty) {
                                                  await alertSnap.data!.docs.first.reference.update({
                                                    'isDone': true,
                                                  });
                                                }

                                                // Show a friendly popup message
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Alert marked as done ✅'),
                                                      duration: Duration(seconds: 2),
                                                    ),
                                                  );
                                                }

                                                Navigator.pop(context);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E3A8A),
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text("Mark as Done"),
                                            ),
                                          ),
                                        ];
                                      }

                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.of(context).viewInsets.bottom,
                                          top: 16,
                                          left: 16,
                                          right: 16,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Center(
                                              child: Container(
                                                width: 50,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Center(
                                              child: Text(
                                                "Recommendation Details",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            const Divider(thickness: 1.2, color: Colors.grey, height: 20),
                                            const SizedBox(height: 8),
                                            Center(
                                              child: Text(
                                                actionTitle,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: actionColor,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              "Reason:",
                                              style: TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            ...reasonWidgets,
                                            const SizedBox(height: 16),
                                            Row(children: buttons),
                                            const SizedBox(height: 20),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Recommendation"),
                          ),
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
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
