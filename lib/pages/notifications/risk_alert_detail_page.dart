import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RiskAlertDetailPage extends StatelessWidget {
  final String riskAnalysisId;
  final String alertId;
  final String userRole; // 🔹 Added this to fix the error in main.dart

  const RiskAlertDetailPage({
    super.key,
    required this.riskAnalysisId,
    required this.alertId,
    required this.userRole, // 🔹 Constructor now requires userRole
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
                // ⚠️ HEADER
                Text(
                  "⚠️ $riskLevel RISK DETECTED",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
                ),
                const SizedBox(height: 16),

                // RISK DETAILS CONTAINER
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

                // RECOMMENDATION BUTTON
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
                    child: const Text("View Mitigation Strategy", style: TextStyle(fontWeight: FontWeight.bold)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        String title = level == "High" ? "IMMEDIATE STOCK CLEARANCE" : "INVENTORY ADJUSTMENT";
        List<String> steps = level == "High"
            ? ["1. Stop all incoming orders for this product", "2. Bundle with fast-moving items", "3. Relocate to 'Quick Sale' section"]
            : ["1. Reduce next order quantity", "2. Monitor daily sales closely", "3. Review pricing strategy"];

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text("Mitigation Strategy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              const Divider(),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: level == "High" ? Colors.red : Colors.orange)),
              const SizedBox(height: 10),
              ...steps.map((step) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(step),
              )),
              const SizedBox(height: 20),

              // 🔹 Shared Action Button (Accessible by Manager and Staff)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // This updates the central 'alerts' collection so both roles see the change
                    if (alertId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('alerts').doc(alertId).update({'isDone': true});
                    }

                    Navigator.pop(context); // Close BottomSheet
                    Navigator.pop(context); // Go back to List

                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Risk marked as handled ✅"))
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
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