import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inventryx/models/forecast_model.dart';
import 'risk_logic.dart';

// [IMPORTANT] Import ManagerPage (The wrapper with the BottomNavBar)
import 'package:inventryx/pages/manager/manager_page.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current User ID

class RiskScoringPage extends StatefulWidget {
  final List<ForecastModel> forecasts;

  const RiskScoringPage({super.key, required this.forecasts});

  @override
  State<RiskScoringPage> createState() => _RiskScoringPageState();
}

class _RiskScoringPageState extends State<RiskScoringPage> {
  List<Map<String, dynamic>> _calculatedRisks = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _calculateAllRisks();
  }

  Future<void> _calculateAllRisks() async {
    List<Map<String, dynamic>> results = [];

    try {
      for (var forecast in widget.forecasts) {

        // 1. GET TOTAL STOCK
        DocumentSnapshot productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(forecast.productId)
            .get();

        int currentStock = 0;
        if (productDoc.exists) {
          currentStock = int.tryParse(productDoc.get('currentStock')?.toString() ?? '0') ?? 0;
        }

        // 2. GET NEAREST EXPIRY DATE
        QuerySnapshot batchSnapshot = await FirebaseFirestore.instance
            .collection('batches')
            .where('productId', isEqualTo: forecast.productId)
            .where('currentQuantity', isGreaterThan: 0)
            .orderBy('currentQuantity')
            .orderBy('expiryDate', descending: false)
            .get();

        int daysToExpiry = 999;

        for (var doc in batchSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['expiryDate'] != null) {
            Timestamp expiryTs = data['expiryDate'];
            DateTime expiryDate = expiryTs.toDate();
            daysToExpiry = expiryDate.difference(DateTime.now()).inDays;
            break;
          }
        }

        // 3. RUN RISK CALCULATION
        RiskResult result = RiskLogic.calculateRisk(
          forecastDemand: forecast.predictedDemand,
          currentStock: currentStock,
          daysToExpiry: daysToExpiry,
        );

        results.add({
          "productId": forecast.productId,
          "productName": forecast.productName,
          "predictedDemand": forecast.predictedDemand,
          "currentStock": currentStock,
          "daysToExpiry": daysToExpiry,
          "riskLevel": result.riskLevel,
          "riskValue": result.riskValue,
          "reasons": result.reasons,
        });
      }

      if (mounted) {
        setState(() {
          _calculatedRisks = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error calculating risk: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SAVE TO DATABASE ---
  Future<void> _saveToDatabase() async {
    setState(() => _isSaving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance.collection('risk_analysis');

      for (var item in _calculatedRisks) {
        DocumentReference docRef = collectionRef.doc();

        batch.set(docRef, {
          'RiskID': docRef.id,
          'ProductName': item['productName'],
          'RiskLevel': item['riskLevel'],
          'RiskValue': item['riskValue'],
          'DaysToExpiry': item['daysToExpiry'],
          'CreatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Risk Analysis Saved Successfully!")),
        );

        // [FIXED] Navigate to ManagerPage (Wrapper) to keep Bottom Navigation Bar
        final currentUser = FirebaseAuth.instance.currentUser;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ManagerPage(
              loggedInUsername: "Manager", // Or fetch from a provider if you have it
              userId: currentUser?.uid ?? "", // Safety check for UID
              username: "", // Optional depending on your ManagerPage logic
            ),
          ),
              (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      debugPrint("Error saving risk: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Risk Scoring", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF233E99)))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _calculatedRisks.length,
              itemBuilder: (context, index) {
                return _buildRiskItem(_calculatedRisks[index]);
              },
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  // --- UI WIDGETS ---

  Widget _buildRiskItem(Map<String, dynamic> item) {
    return Column(
      children: [
        // Grey Info Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow("Product Name:", item['productName']),
              _buildInfoRow("Predicted Demand:", "${item['predictedDemand'].round()} units"),
              _buildInfoRow("Current Stock:", "${item['currentStock']} units"),
              _buildInfoRow("Days Until Expiry:", item['daysToExpiry'] == 999 ? "N/A" : "${item['daysToExpiry']} days"),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Risk Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getRiskColor(item['riskLevel']),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _getRiskColor(item['riskLevel']).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Risk Level: ${item['riskLevel']}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text("Reasons:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...(item['reasons'] as List<String>).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(color: Colors.white)),
                    Expanded(child: Text(r, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3))),
                  ],
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveToDatabase,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF233E99),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Save", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case "High": return const Color(0xFFE53935);
      case "Medium": return const Color(0xFFFFB74D);
      case "Low": return const Color(0xFF43A047);
      default: return Colors.grey;
    }
  }
}