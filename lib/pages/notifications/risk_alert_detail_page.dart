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
          if (!riskSnap.data!.exists) return const Center(child: Text("Risk data no longer exists."));

          final risk = riskSnap.data!.data() as Map<String, dynamic>;

          // 🔹 Matches "ProductName" (Capital P) in your risk_analysis screenshot
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

                // 🔹 FIXED: Image Retrieval Section
                FutureBuilder<QuerySnapshot>(
                  // Fetch all products to avoid the indexing requirement for specific 'where' queries
                  future: FirebaseFirestore.instance.collection('products').get(),
                  builder: (context, prodQuerySnap) {
                    if (prodQuerySnap.hasError) return const Icon(Icons.error);

                    String? imageUrl;
                    if (prodQuerySnap.hasData) {
                      // Manually find the product that matches the name
                      try {
                        final matchingDoc = prodQuerySnap.data!.docs.firstWhere(
                                (doc) => (doc.data() as Map<String, dynamic>)['productName'] == productName
                        );
                        imageUrl = (matchingDoc.data() as Map<String, dynamic>)['imageUrl'];
                      } catch (e) {
                        // No match found
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

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showRecommendationSheet(context, riskLevel, alertId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Recommendation", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRecommendationSheet(BuildContext context, String level, String alertId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        bool isHigh = level == "High";

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text("Scoring Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
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

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (alertId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('alerts').doc(alertId).update({'isDone': true});
                    }
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Risk marked as handled ✅"))
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Mark as Handled"),
                ),
              )
            ],
          ),
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}