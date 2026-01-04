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
          "Risk Analysis Detail",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
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
          String statusIcon = riskLevel == "High" ? "🔥" : "⚠️";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. RISK BANNER
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Text(statusIcon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "$riskLevel RISK DETECTED",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. RISK INFO CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Inventory Risk Metrics",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 15),
                      const Divider(),
                      const SizedBox(height: 15),

                      Text(
                        productName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)),
                      ),
                      const SizedBox(height: 25),

                      // Metrics Grid
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            _buildDetailRow("Risk Score", "$riskValue / 100", valueColor: statusColor, isBold: true),
                            _buildDetailRow("Risk Level", riskLevel, isBold: true),
                            _buildDetailRow("Nearest Expiry", daysToExpiry == 999 ? "N/A" : "$daysToExpiry days"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        "This score is calculated based on the ratio between current stock levels and predicted demand trends.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 3. ACTION BUTTON
                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => _showRecommendationSheet(context, riskLevel, alertId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text("View Recommendation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- HELPER UNTUK ROW BIASA ---
  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          Text(
              value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? Colors.black87
              )
          ),
        ],
      ),
    );
  }

  // --- RECOMMENDATION MODAL ---
  void _showRecommendationSheet(BuildContext context, String level, String alertId) {
    bool isHigh = level == "High";
    Color actionColor = isHigh ? Colors.red : Colors.orange;
    String actionTitle = isHigh ? "IMMEDIATE CLEARANCE" : "ADJUST INVENTORY";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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

              const Center(child: Text("Risk Analysis Report", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              const SizedBox(height: 20),

              // REASON SECTION
              const Text("Why is this flagged?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 8),
              if (isHigh) ...[
                _buildBulletPoint("Stock is 3x higher than forecast demand."),
                _buildBulletPoint("Upcoming expiry in less than 7 days."),
                _buildBulletPoint("Sales trend shows a significant decrease."),
              ] else ...[
                _buildBulletPoint("Stock levels slightly exceed forecast."),
                _buildBulletPoint("Expiry within 14 days window."),
              ],

              const SizedBox(height: 20),

              // ACTION SECTION
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
                    Text(actionTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: actionColor, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    if (isHigh) ...[
                      _buildBulletPoint("1. Stop incoming orders."),
                      _buildBulletPoint("2. Bundle with fast-moving items."),
                      _buildBulletPoint("3. Move to 'Clearance' section."),
                    ] else ...[
                      _buildBulletPoint("1. Reduce next order quantity."),
                      _buildBulletPoint("2. Monitor sales closely."),
                      _buildBulletPoint("3. Review pricing strategy."),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // BUTTONS
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
                      onPressed: () async {
                        if (alertId.isNotEmpty) {
                          await FirebaseFirestore.instance.collection('alerts').doc(alertId).update({'isDone': true});
                        }
                        Navigator.pop(context); // Close modal
                        Navigator.pop(context); // Close page
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Risk marked as handled ✅"), backgroundColor: Colors.green)
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Mark as Handled"),
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
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontSize: 16, height: 1.2)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.3))),
        ],
      ),
    );
  }
}