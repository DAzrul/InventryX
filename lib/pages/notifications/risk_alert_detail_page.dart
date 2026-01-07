import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RiskAlertDetailPage extends StatelessWidget {
  final String riskAnalysisId;
  final String alertId;
  final String userRole;

  const RiskAlertDetailPage({
    super.key,
    required this.riskAnalysisId,
    required this.alertId,
    required this.userRole,
  });

  // Standard Colors
  final Color primaryBlue = const Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Risk Analysis Detail",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('risk_analysis').doc(riskAnalysisId).get(),
        builder: (context, riskSnap) {
          if (!riskSnap.hasData) return const Center(child: CircularProgressIndicator());

          // Handle jika data risk sudah dipadam
          if (!riskSnap.data!.exists) return const Center(child: Text("Risk data no longer exists."));

          final risk = riskSnap.data!.data() as Map<String, dynamic>;

          final String productName = risk['ProductName'] ?? "Unknown";
          final String riskLevel = risk['RiskLevel'] ?? "Medium";
          final int riskValue = risk['RiskValue'] ?? 0;
          final int daysToExpiry = risk['DaysToExpiry'] ?? 0;

          Color statusColor = riskLevel == "High" ? Colors.red : Colors.orange;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "⚠️ $riskLevel RISK DETECTED",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
                ),
                const SizedBox(height: 16),

                // Papar Gambar Produk
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('products').get(),
                  builder: (context, prodQuerySnap) {
                    if (prodQuerySnap.hasError) return const Icon(Icons.error);

                    String? imageUrl;
                    if (prodQuerySnap.hasData) {
                      try {
                        // Cari produk berdasarkan nama (Safe check)
                        final matchingDocs = prodQuerySnap.data!.docs.where(
                                (doc) => (doc.data() as Map<String, dynamic>)['productName'] == productName
                        );

                        if (matchingDocs.isNotEmpty) {
                          imageUrl = (matchingDocs.first.data() as Map<String, dynamic>)['imageUrl'];
                        }
                      } catch (e) {
                        imageUrl = null;
                      }
                    }

                    return Center(
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                          )
                              : const Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),

                // Info Kad
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text("Inventory Risk Metrics",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Divider(thickness: 1.2, height: 20, color: Colors.grey),

                      const SizedBox(height: 10),
                      Text(productName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),

                      _row("Risk Score", "$riskValue / 100"),
                      _row("Risk Level", riskLevel),
                      _row("Days to Nearest Expiry", daysToExpiry == 999 ? "N/A" : "$daysToExpiry days"),
                      const Divider(),
                      const Text(
                        "This risk is calculated based on the ratio between current stock levels and predicted demand from your recent sales history.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Butang Recommendation
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRecommendationSheet(context, riskLevel, alertId),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text(
                        "View Recommendation",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🔹 FUNGSI YANG DIPERBAIKI (ANTI-CRASH)
  void _showRecommendationSheet(BuildContext context, String level, String alertId) {
    bool isHigh = level == "High";

    // Helper untuk bina UI dalam BottomSheet (Supaya tak perlu tulis kod 2 kali)
    Widget buildSheetContent(bool isDone, bool canInteract) {
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
            const Divider(thickness: 1, height: 20),

            Text("Risk Level: $level", style: TextStyle(fontWeight: FontWeight.bold, color: isHigh ? Colors.red : Colors.orange)),
            const SizedBox(height: 8),
            const Text("Reason:", style: TextStyle(fontWeight: FontWeight.bold)),
            if (isHigh) ...[
              const Text("• Stock is 3× higher than forecast"),
              const Text("• Expiry in 6 days"),
              const Text("• Sales trend decreasing"),
            ] else ...[
              const Text("• Stock slightly higher than forecast"),
              const Text("• Expiry within 14 days"),
            ],

            const SizedBox(height: 20),

            const Center(child: Text("Recommended Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            const Divider(thickness: 1, height: 20),
            Text(isHigh ? "IMMEDIATE STOCK CLEARANCE" : "INVENTORY ADJUSTMENT",
                style: TextStyle(fontWeight: FontWeight.bold, color: isHigh ? Colors.red : Colors.orange)),
            const SizedBox(height: 10),
            if (isHigh) ...[
              const Text("1. Stop all incoming orders for this product"),
              const Text("2. Bundle with fast-moving items"),
              const Text("3. Relocate to 'Quick Sale' section"),
            ] else ...[
              const Text("1. Reduce next order quantity"),
              const Text("2. Monitor daily sales closely"),
              const Text("3. Review pricing strategy"),
            ],

            const SizedBox(height: 30),

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
                    // 🔹 FIX: Disable button jika sudah Done ATAU jika alertId kosong (canInteract = false)
                    onPressed: (isDone || !canInteract) ? null : () async {
                      if (alertId.isNotEmpty) {
                        await FirebaseFirestore.instance.collection('alerts').doc(alertId).update({'isDone': true});
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Risk marked as handled ✅"), backgroundColor: Colors.green)
                          );
                        }
                      }
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
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // 🔹 SAFETY CHECK: Jika alertId kosong, jangan panggil Firebase!
        if (alertId.isEmpty) {
          // Papar UI tapi disable fungsi 'Mark as Done'
          return buildSheetContent(false, false);
        }

        // Jika alertId ada, baru fetch status dari Firebase
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('alerts').doc(alertId).get(),
          builder: (context, alertSnap) {
            bool isDone = false;
            if (alertSnap.hasData && alertSnap.data!.exists) {
              isDone = (alertSnap.data!.data() as Map<String, dynamic>)['isDone'] ?? false;
            }
            return buildSheetContent(isDone, true);
          },
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
