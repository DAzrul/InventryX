import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inventryx/models/forecast_model.dart';
import 'risk_logic.dart';
import 'package:inventryx/pages/manager/manager_page.dart';

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

  final Color primaryColor = const Color(0xFF233E99);
  final Color bgGrey = const Color(0xFFF4F7FF);

  @override
  void initState() {
    super.initState();
    _calculateAllRisks();
  }

  Future<void> _calculateAllRisks() async {
    List<Map<String, dynamic>> results = [];
    try {
      for (var forecast in widget.forecasts) {
        // 1. Fetch using currentStock field name
        DocumentSnapshot productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(forecast.productId)
            .get();

        int currentStock = 0;
        if (productDoc.exists) {
          // UPDATED: Changed from quantityInStock to currentStock
          currentStock = int.tryParse(productDoc.get('currentStock')?.toString() ?? '0') ?? 0;
        }

        // 2. Fetch Earliest Expiry
        QuerySnapshot batchSnapshot = await FirebaseFirestore.instance
            .collection('batches')
            .where('productId', isEqualTo: forecast.productId)
            .orderBy('expiryDate', descending: false)
            .get();

        int daysToExpiry = 999;
        for (var doc in batchSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          int qty = int.tryParse(data['currentQuantity']?.toString() ?? '0') ?? 0;
          if (qty > 0 && data['expiryDate'] != null) {
            Timestamp expiryTs = data['expiryDate'];
            daysToExpiry = expiryTs.toDate().difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
            break;
          }
        }

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
      if (mounted) setState(() { _calculatedRisks = results; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToDatabase() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final batch = FirebaseFirestore.instance.batch();
      for (var item in _calculatedRisks) {
        DocumentReference docRef = FirebaseFirestore.instance.collection('risk_analysis').doc();
        batch.set(docRef, {
          'RiskID': docRef.id,
          'ProductName': item['productName'],
          'RiskLevel': item['riskLevel'],
          'RiskValue': item['riskValue'],
          'DaysToExpiry': item['daysToExpiry'],
          'CreatedAt': FieldValue.serverTimestamp(),
          'CreatedBy': user.uid,
        });
      }
      await batch.commit();
      await FirebaseFirestore.instance.collection('forecast_drafts').doc(user.uid).delete();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => ManagerPage(loggedInUsername: "Manager", userId: user.uid, username: "")), (route) => false);
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(title: const Text("Risk Scoring Analysis", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: _isLoading ? Center(child: CircularProgressIndicator(color: primaryColor)) : Column(
        children: [
          Expanded(child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: _calculatedRisks.length, itemBuilder: (context, index) => _buildRiskItem(_calculatedRisks[index]))),
          _buildSaveButton(),
        ],
      ),
    );
  }
  Widget _buildRiskItem(Map<String, dynamic> item) {
    String level = item['riskLevel'];
    Color statusColor = _getRiskColor(level);
    int stock = item['currentStock'];

    // Change title only for Stock = 0 (Urgent)
    String titleText = (level == "Urgent")
        ? "URGENT!"
        : "$level Risk Detected";

    return Column(
      children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['productName'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 15),
            Row(children: [
              _buildStatBox("Forecast", "${item['predictedDemand'].round()}", Icons.show_chart_rounded, Colors.blue),
              const SizedBox(width: 10),
              // Stock turns Red if 0, but Purple/Blue if healthy or low
              _buildStatBox("Stock", "$stock", Icons.inventory_2_rounded, stock <= 0 ? Colors.red : (stock <= 10 ? Colors.orange : Colors.purple)),
              const SizedBox(width: 10),
              _buildStatBox("Expiry", item['daysToExpiry'] >= 999 ? "-" : "${item['daysToExpiry']}d", Icons.access_time_filled_rounded, item['daysToExpiry'] <= 7 ? Colors.red : Colors.orange),
            ]),
          ]),
        ),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: statusColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titleText, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
            const SizedBox(height: 12),
            ...(item['reasons'] as List<String>).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text("• $r", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            )),
          ]),
        ),
        const SizedBox(height: 25),
      ],
    );
  }

  Color _getRiskColor(String level) {
    if (level == "Urgent") return const Color(0xFFB71C1C); // Deep Red
    if (level == "High") return const Color(0xFFE53935);   // Bright Red
    if (level == "Medium") return const Color(0xFFFFA726); // Orange
    return const Color(0xFF43A047);                         // Green
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(icon, size: 18, color: color), const SizedBox(height: 6), Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)), Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.bold))])));
  }

  Widget _buildSaveButton() {
    return Container(padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))), child: SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isSaving ? null : _saveToDatabase, style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Analysis Result", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)))));
  }

}