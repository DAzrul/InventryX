import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 🔹 Import the forecast page
import '../manager/forecast/forecast.dart';

class LowStockAlertDetailPage extends StatelessWidget {
  final String productId;
  final String alertId;
  final String userRole;

  const LowStockAlertDetailPage({
    super.key,
    required this.productId,
    required this.alertId,
    required this.userRole,
  });

  final Color primaryBlue = const Color(0xFF1E3A8A);
  final Color bgGrey = const Color(0xFFF8FAFF);

  @override
  Widget build(BuildContext context) {
    if (productId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Product ID is missing.")),
      );
    }

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Low Stock Alert Detail",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
        builder: (context, productSnap) {
          if (productSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!productSnap.hasData || !productSnap.data!.exists) {
            return const Center(child: Text("Product details not found."));
          }

          final product = productSnap.data!.data() as Map<String, dynamic>;
          final int currentStock = int.tryParse(product['currentStock']?.toString() ?? '0') ?? 0;
          final int reorderLevel = int.tryParse(product['reorderLevel']?.toString() ?? '0') ?? 0;
          final String supplierId = product['supplierId'] ?? '';

          return FutureBuilder<DocumentSnapshot?>(
            future: supplierId.isNotEmpty
                ? FirebaseFirestore.instance.collection('supplier').doc(supplierId).get()
                : Future.value(null),
            builder: (context, supplierSnap) {
              String supplierName = "Unknown Supplier";
              if (supplierSnap.hasData && supplierSnap.data != null && supplierSnap.data!.exists) {
                final sData = supplierSnap.data!.data() as Map<String, dynamic>;
                supplierName = sData['supplierName'] ?? "Unknown Supplier";
              }

              Color statusColor = Colors.orange.shade800;
              if (currentStock == 0) statusColor = Colors.red;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.trending_down_rounded, color: statusColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              currentStock == 0 ? "OUT OF STOCK" : "LOW STOCK WARNING",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${product['subCategory'] ?? '-'} • ${product['category'] ?? '-'}",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),
                          _buildDetailRow("Supplier", supplierName),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              children: [
                                _buildDetailRow("Current Stock", "$currentStock Units", isBold: true, valueColor: statusColor),
                                _buildDetailRow("Reorder Level", "$reorderLevel Units", isBold: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () => _showRecommendation(context, currentStock, reorderLevel, alertId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
                        label: const Text("View Recommendation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecommendation(BuildContext context, int stock, int reorder, String alertId) {
    Color actionColor = (stock == 0) ? Colors.red : Colors.orange.shade900;
    String actionTitle = (stock == 0) ? "URGENT REPLENISHMENT" : "RESTOCK IMMEDIATELY";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // 🔹 Use StreamBuilder here to listen to the alert's isDone status in real-time
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('alerts').doc(alertId).snapshots(),
          builder: (context, snapshot) {
            bool isDone = false;
            if (snapshot.hasData && snapshot.data!.exists) {
              isDone = snapshot.data!.get('isDone') ?? false;
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
                        Text(actionTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: actionColor)),
                        const SizedBox(height: 10),
                        _bulletPoint("Current stock level ($stock) is critical."),
                        _bulletPoint("Contact supplier to place a new order."),
                        _bulletPoint("Re-verify if there are pending deliveries."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"),
                        ),
                      ),
                      // 🔹 Display "Start Forecasting" only if Manager AND Alert is NOT done
                      if (userRole.toLowerCase() == 'manager' && !isDone) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                            onPressed: () async {
                              // 1. Mark as Done in Firestore
                              if (alertId.isNotEmpty) {
                                await FirebaseFirestore.instance
                                    .collection('alerts')
                                    .doc(alertId)
                                    .update({'isDone': true});
                              }

                              if (context.mounted) {
                                // 2. Navigate to Forecasting Page
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ForecastingPage()),
                                );
                              }
                            },
                            child: const Text("Start Forecasting", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
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

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}