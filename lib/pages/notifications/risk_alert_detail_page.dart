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

  final Color primaryBlue = const Color(0xFF1E3A8A);
  final Color bgGrey = const Color(0xFFF8FAFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
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
          final int daysToExpiry = risk['DaysToExpiry'] ?? 0;

          Color statusColor = riskLevel == "High" ? Colors.red : Colors.orange;

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
                      Icon(Icons.warning_amber_rounded, color: statusColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "⚠️ ${riskLevel.toUpperCase()} RISK DETECTED",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
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
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('products').get(),
                    builder: (context, prodQuerySnap) {
                      String? imageUrl;
                      String subCategory = "-";
                      String category = "-";

                      if (prodQuerySnap.hasData) {
                        try {
                          final matchingDocs = prodQuerySnap.data!.docs.where(
                                  (doc) => (doc.data() as Map<String, dynamic>)['productName'] == productName
                          );
                          if (matchingDocs.isNotEmpty) {
                            final productData = matchingDocs.first.data() as Map<String, dynamic>;
                            imageUrl = productData['imageUrl'];
                            subCategory = productData['subCategory'] ?? "-";
                            category = productData['category'] ?? "-";
                          }
                        } catch (e) { imageUrl = null; }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              constraints: const BoxConstraints(
                                maxHeight: 150,
                                minHeight: 100,
                              ),
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                )
                                    : Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                              ),
                            ),
                          ),

                          Center(
                            child: Text(
                              productName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),

                          Center(
                            child: Text(
                              "$subCategory • $category",
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 6),

                          _row("Risk Level", riskLevel.toUpperCase(), color: statusColor),
                          _row("Days to Nearest Expiry", daysToExpiry == 999 ? "N/A" : "$daysToExpiry days", color: statusColor),

                          const Divider(height: 30),
                          const Text(
                            "Reason:",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                          ),
                          const SizedBox(height: 8),
                          if (riskLevel == "High") ...[
                            _bulletPoint("Stock is 3× higher than forecast"),
                            _bulletPoint("Expiry in 6 days"),
                            _bulletPoint("Sales trend decreasing"),
                          ] else ...[
                            _bulletPoint("Stock slightly higher than forecast"),
                            _bulletPoint("Expiry within 14 days"),
                          ],

                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                            child: const Text(
                              "This risk is calculated based on the ratio between current stock levels and forecasted demand.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  height: 55,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
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

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecommendationSheet(BuildContext context, String level, String alertId) {
    bool isHigh = level == "High";
    Color actionColor = isHigh ? Colors.red : Colors.orange;

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                "Recommended Action",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Action Box styling matches Expiry Page
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
                  Text(
                    isHigh ? "IMMEDIATE STOCK CLEARANCE" : "INVENTORY ADJUSTMENT",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: actionColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (isHigh) ...[
                    _buildSheetBulletPoint("Stop all incoming orders for this product."),
                    _buildSheetBulletPoint("Bundle with fast-moving items."),
                    _buildSheetBulletPoint("Relocate to 'Quick Sale' section."),
                  ] else ...[
                    _buildSheetBulletPoint("Reduce next order quantity."),
                    _buildSheetBulletPoint("Monitor daily sales closely."),
                    _buildSheetBulletPoint("Review pricing strategy."),
                  ],

                  _urgencyBadge(isHigh ? "CRITICAL" : "MEDIUM", actionColor),
                ],
              ),
            ),

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
        if (alertId.isEmpty) return buildSheetContent(false, false);
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

  Widget _buildSheetBulletPoint(String text) {
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
      child: Text(
        "Urgency: $level",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: color ?? primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}