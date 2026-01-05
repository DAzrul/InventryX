import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpiryAlertDetailPage extends StatelessWidget {
  final String batchId;
  final String productId;
  final String stage;
  final String userRole;

  const ExpiryAlertDetailPage({
    super.key,
    required this.batchId,
    required this.productId,
    required this.stage,
    required this.userRole,
  });

  // Warna standard
  final Color primaryBlue = const Color(0xFF1E3A8A);
  final Color bgGrey = const Color(0xFFF8FAFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        // --- [SIMBOL ANAK PANAH (<) DI SINI] ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        // ---------------------------------------
        title: const Text(
          "Expiry Alert Detail",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('batches').doc(batchId).get(),
        builder: (context, batchSnap) {
          if (!batchSnap.hasData) return const Center(child: CircularProgressIndicator());

          final batch = batchSnap.data!.data() as Map<String, dynamic>;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
            builder: (context, productSnap) {
              if (!productSnap.hasData) return const Center(child: CircularProgressIndicator());

              final product = productSnap.data!.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('supplier')
                    .doc(product['supplierId'])
                    .get(),
                builder: (context, supplierSnap) {
                  if (!supplierSnap.hasData) return const Center(child: CircularProgressIndicator());

                  final supplier = supplierSnap.data!.data() as Map<String, dynamic>;

                  // --- LOGIC TARIKH ---
                  final expiryRaw = (batch['expiryDate'] as Timestamp).toDate();
                  final createdAt = (batch['createdAt'] as Timestamp).toDate();
                  final today = DateTime.now();
                  final todayDate = DateTime(today.year, today.month, today.day);
                  final expiryDate = DateTime(expiryRaw.year, expiryRaw.month, expiryRaw.day);
                  final daysLeft = expiryDate.difference(todayDate).inDays;

                  // --- LOGIC WARNA STATUS ---
                  Color statusColor;
                  String statusText;
                  IconData statusIcon;

                  if (stage == "expired") {
                    statusText = "CRITICAL: EXPIRED";
                    statusColor = Colors.red;
                    statusIcon = Icons.error_outline;
                  } else if (stage == "3") {
                    statusText = "WARNING: EXPIRY IN 3 DAYS";
                    statusColor = Colors.orange[900]!;
                    statusIcon = Icons.access_time_filled;
                  } else if (stage == "5") {
                    statusText = "ALERT: EXPIRY IN 5 DAYS";
                    statusColor = Colors.amber[800]!;
                    statusIcon = Icons.access_time;
                  } else {
                    statusText = "EXPIRY SOON ($stage Days)";
                    statusColor = Colors.orange;
                    statusIcon = Icons.info_outline;
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. STATUS BANNER
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(statusIcon, color: statusColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  statusText,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2. PRODUCT INFO CARD
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            children: [
                              if (product['imageUrl'] != null && product['imageUrl'].isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(product['imageUrl'], height: 120, width: 120, fit: BoxFit.cover),
                                )
                              else
                                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),

                              const SizedBox(height: 16),

                              Text(
                                product['productName'] ?? 'Unknown Product',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${product['subCategory']} • ${product['category']}",
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),

                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 10),

                              // BUTIRAN
                              _buildDetailRow("Supplier", supplier['supplierName']),
                              _buildDetailRow("Stock In Date", "${createdAt.day}/${createdAt.month}/${createdAt.year}"),
                              const SizedBox(height: 10),

                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                                child: Column(
                                  children: [
                                    _buildDetailRow("Batch Number", batch['batchNumber'], isBold: true),
                                    _buildDetailRow("Current Quantity", batch['currentQuantity'].toString(), isBold: true),
                                    const Divider(height: 20),
                                    _buildDetailRow(
                                        "Expiry Date",
                                        "${expiryDate.day}/${expiryDate.month}/${expiryDate.year}",
                                        valueColor: Colors.red, isBold: true
                                    ),
                                    _buildDetailRow(
                                        "Days Remaining",
                                        daysLeft <= 0 ? "Expired" : "$daysLeft Days",
                                        valueColor: daysLeft <= 0 ? Colors.red : Colors.orange[800], isBold: true
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // 3. ACTION BUTTON
                        SizedBox(
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: () => _showRecommendation(context, stage, batchId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.lightbulb_outline),
                            label: const Text("View Recommendation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // --- HELPER UNTUK ROW BIASA ---
  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? Colors.black87
              )
          ),
        ],
      ),
    );
  }

  // --- RECOMMENDATION MODAL ---
  void _showRecommendation(BuildContext context, String stage, String batchId) {
    String actionTitle = "";
    Color actionColor = Colors.black;
    List<Widget> reasonWidgets = [];

    // Logic Recommendation
    if (stage == "5") {
      actionTitle = "APPLY DISCOUNT";
      actionColor = Colors.amber[800]!;
      reasonWidgets = [
        _buildBulletPoint("Product expires in 5 days."),
        _buildBulletPoint("Suggested Discount: 10% - 20% to clear stock."),
        _urgencyBadge("MEDIUM", actionColor),
      ];
    } else if (stage == "3") {
      actionTitle = "SHELF ROTATION / CLEARANCE";
      actionColor = Colors.orange[900]!;
      reasonWidgets = [
        _buildBulletPoint("Product expires in 3 days."),
        _buildBulletPoint("Move to front shelf (eye-level) or Clearance bin."),
        _urgencyBadge("HIGH", actionColor),
      ];
    } else if (stage == "expired") {
      actionTitle = "DISPOSE / RETURN";
      actionColor = Colors.red;
      reasonWidgets = [
        _buildBulletPoint("Product has passed expiry date."),
        _buildBulletPoint("Remove from shelf immediately."),
        _buildBulletPoint("Update stock status to 'Written Off'."),
        _urgencyBadge("CRITICAL", actionColor),
      ];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('alerts')
              .where('batchId', isEqualTo: batchId)
              .where('expiryStage', isEqualTo: stage)
              .limit(1)
              .get(),
          builder: (context, alertSnap) {
            if (!alertSnap.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));

            bool isDone = false;
            if (alertSnap.data!.docs.isNotEmpty) {
              isDone = alertSnap.data!.docs.first['isDone'] ?? false;
            }

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),

                  const Center(child: Text("Recommended Action", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: actionColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(actionTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: actionColor, letterSpacing: 1.0)),
                        const SizedBox(height: 10),
                        ...reasonWidgets,
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Close", style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isDone
                              ? null
                              : () async {
                            if (alertSnap.data!.docs.isNotEmpty) {
                              await alertSnap.data!.docs.first.reference.update({'isDone': true});
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Action marked as completed ✅'), backgroundColor: Colors.green),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDone ? Colors.grey : primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(isDone ? "Completed" : "Mark as Done"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.3))),
        ],
      ),
    );
  }

  Widget _urgencyBadge(String level, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text("Urgency: $level", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}