import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inventryx/models/forecast_model.dart';
import 'risk_logic.dart';

// [PENTING] Import ManagerPage (Wrapper Utama)
import 'package:inventryx/pages/manager/manager_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // --- LOGIK PENGIRAAN RISIKO (CORRECTED) ---
  Future<void> _calculateAllRisks() async {
    List<Map<String, dynamic>> results = [];

    try {
      for (var forecast in widget.forecasts) {

        // 1. Dapatkan Stok Semasa
        DocumentSnapshot productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(forecast.productId)
            .get();

        int currentStock = 0;
        if (productDoc.exists) {
          currentStock = int.tryParse(productDoc.get('currentStock')?.toString() ?? '0') ?? 0;
        }

        // 2. Dapatkan Tarikh Luput (FIXED LOGIC)
        // We query purely by Date ASCENDING to ensure we look at the calendar order.
        QuerySnapshot batchSnapshot = await FirebaseFirestore.instance
            .collection('batches')
            .where('productId', isEqualTo: forecast.productId)
            .orderBy('expiryDate', descending: false) // Sort 14/1 -> 16/1 -> 18/1 -> 20/1
            .get();

        int daysToExpiry = 999; // Default Safe

        // Loop through batches in chronological order
        for (var doc in batchSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          int qty = int.tryParse(data['currentQuantity']?.toString() ?? '0') ?? 0;

          // LOGIC: Only pick this date if the batch actually has stock
          if (qty > 0 && data['expiryDate'] != null) {
            Timestamp expiryTs = data['expiryDate'];
            DateTime expiryDate = expiryTs.toDate();
            daysToExpiry = expiryDate.difference(DateTime.now()).inDays;
            break; // Found the earliest active batch! Stop looking.
          }
          // If qty is 0, the loop continues to the next date (e.g. 14/1 -> 16/1 -> 18/1)
        }

        // 3. Jalankan Pengiraan Risiko
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

  // --- SAVE TO DATABASE & AUTO DELETE DRAFT ---
  Future<void> _saveToDatabase() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance.collection('risk_analysis');

      // 1. Simpan Data Analisis Risiko
      for (var item in _calculatedRisks) {
        DocumentReference docRef = collectionRef.doc();
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

      // 2. Commit Simpanan
      await batch.commit();

      // 3. [PENTING] Padam Draf (Sebab kerja dah siap)
      await FirebaseFirestore.instance
          .collection('forecast_drafts')
          .doc(user.uid)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Analysis Saved & Draft Cleared!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 4. Kembali ke ManagerPage (Home) dengan betul
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ManagerPage(
              loggedInUsername: "Manager", // Atau tarik dari provider/shared_prefs
              userId: user.uid,
              username: "",
            ),
          ),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Error saving risk: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Text(
          "Risk Scoring Analysis",
          style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
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

  // --- UI WIDGETS (PREMIUM STYLE) ---

  Widget _buildRiskItem(Map<String, dynamic> item) {
    String level = item['riskLevel'];
    Color statusColor = _getRiskColor(level);

    return Column(
      children: [
        // KAD MAKLUMAT (Atas)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  item['productName'],
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A1C1E))
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  _buildStatBox("Forecast", "${item['predictedDemand'].round()}", Icons.show_chart_rounded, Colors.blue),
                  const SizedBox(width: 10),
                  _buildStatBox("Stock", "${item['currentStock']}", Icons.inventory_2_rounded, Colors.purple),
                  const SizedBox(width: 10),
                  _buildStatBox("Expiry", item['daysToExpiry'] == 999 ? "-" : "${item['daysToExpiry']}d", Icons.access_time_filled_rounded, Colors.orange),
                ],
              ),
            ],
          ),
        ),

        // KAD RISIKO (Bawah - Sambung dengan atas)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            boxShadow: [BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "$level Risk Detected",
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...(item['reasons'] as List<String>).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(r, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3, fontWeight: FontWeight.w500))),
                  ],
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 25), // Jarak antara item
      ],
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveToDatabase,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 5,
            shadowColor: primaryColor.withOpacity(0.4),
          ),
          child: _isSaving
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text("Save Analysis Result", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case "High": return const Color(0xFFE53935); // Merah Terang
      case "Medium": return const Color(0xFFFFA726); // Oren
      case "Low": return const Color(0xFF43A047); // Hijau
      default: return Colors.grey;
    }
  }
}