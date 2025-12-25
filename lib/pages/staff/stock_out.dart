import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_incoming_stock.dart';

class StockOutPage extends StatefulWidget {
  const StockOutPage({super.key});

  @override
  State<StockOutPage> createState() => _StockOutPageState();
}

class _StockOutPageState extends State<StockOutPage> {
  final Color mainBlue = const Color(0xFF00147C);
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentSubTab = 0;
  bool _autoDeduct = true;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: mainBlue,
        elevation: 0,
        title: const Text('Record Outgoing Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTopPageSwitcher(),
          _buildSubTabSwitcher(),
          Expanded(
            child: _currentSubTab == 0
                ? _buildSoldTab()
                : const Center(child: Text("Others Tab Content")),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPageSwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Stock In')),
          ButtonSegment(value: 1, label: Text('Stock Out')),
        ],
        selected: const {1},
        onSelectionChanged: (value) {
          if (value.first == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddIncomingStockPage()));
          }
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          selectedBackgroundColor: mainBlue,
          selectedForegroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSubTabSwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _subTabBtn('Sold', 0),
          const SizedBox(width: 8),
          _subTabBtn('Others', 1),
        ],
      ),
    );
  }

  Widget _subTabBtn(String label, int index) {
    bool sel = _currentSubTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: sel ? mainBlue : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.black, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildSoldTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.grey),
              const SizedBox(width: 12),
              Text(DateFormat('MM/dd/yyyy').format(DateTime.now()), style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search product',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Apply Auto-Deduction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Switch(
                      value: _autoDeduct,
                      activeColor: mainBlue,
                      onChanged: (v) => setState(() => _autoDeduct = v)
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('sales').where('status', isEqualTo: 'pending_deduction').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No pending sales."));

              final salesDocs = snapshot.data!.docs;

              return FutureBuilder<Map<String, int>>(
                  future: _calculateTotals(salesDocs),
                  builder: (context, totalSnapshot) {
                    int tPrev = 0;
                    int tSold = 0;
                    int tAutoResult = 0;

                    if (totalSnapshot.hasData) {
                      tPrev = totalSnapshot.data!['prev']!;
                      tSold = totalSnapshot.data!['sold']!;
                      // LOGIC FOOTER: Bila switch OFF, total jadi 0
                      tAutoResult = _autoDeduct ? (tPrev - tSold) : 0;
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: salesDocs.length,
                            itemBuilder: (context, index) {
                              final sale = salesDocs[index].data() as Map<String, dynamic>;
                              return _buildSaleDeductionCard(sale);
                            },
                          ),
                        ),
                        _buildApplyFooter(tPrev, tSold, tAutoResult),
                      ],
                    );
                  }
              );
            },
          ),
        ),
      ],
    );
  }

  Future<Map<String, int>> _calculateTotals(List<QueryDocumentSnapshot> docs) async {
    int prevTotal = 0;
    int soldTotal = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      soldTotal += (data['quantitySold'] as int? ?? 0);
      var pDoc = await _db.collection('products').doc(data['productID']).get();
      if (pDoc.exists) {
        prevTotal += (pDoc.data()?['currentStock'] as int? ?? 0);
      }
    }
    return {'prev': prevTotal, 'sold': soldTotal};
  }

  Widget _buildSaleDeductionCard(Map<String, dynamic> sale) {
    return FutureBuilder<DocumentSnapshot>(
        future: _db.collection('products').doc(sale['productID']).get(),
        builder: (context, prodSnap) {
          if (!prodSnap.hasData) return const SizedBox.shrink();
          final prodData = prodSnap.data!.data() as Map<String, dynamic>? ?? {};

          final int prevStock = prodData['currentStock'] ?? 0;
          final int soldQty = sale['quantitySold'] ?? 0;

          // LOGIC KAD: Bila switch OFF, Auto-Deducted paparkan 0
          final int autoDeductedValue = _autoDeduct ? (prevStock - soldQty) : 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale['snapshotName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("SKU: ${prodData['barcodeNo'] ?? '-'}  •  Unit: ${prodData['unit'] ?? 'pcs'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statColumn("Prev Stock", prevStock.toString()),
                    _statColumn("Auto-Deducted", autoDeductedValue.toString(), color: _autoDeduct ? Colors.blue[900] : Colors.grey),
                    _statColumn("Sold", soldQty.toString(), color: Colors.orange[800]),
                  ],
                )
              ],
            ),
          );
        }
    );
  }

  Widget _statColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color ?? Colors.black)),
      ],
    );
  }

  Widget _buildApplyFooter(int tPrev, int tSold, int tAutoResult) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))]
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rowSummary("Total Previous Stock", tPrev.toString()),
            _rowSummary("Total Sold", tSold.toString()),
            _rowSummary("Total Auto-Deducted Stock", tAutoResult.toString()),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearPendingSales,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Cancel", style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isProcessing ? null : _applyStockDeduction,
                    child: _isProcessing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Apply", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- Fungsi Cancel & Apply tetap sama logic dia ---
  Future<void> _clearPendingSales() async {
    bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Cancel Sales?"),
          content: const Text("This will delete all pending sales from the list."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Stay")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red))),
          ],
        )
    ) ?? false;
    if (!confirm) return;
    setState(() => _isProcessing = true);
    try {
      final salesQuery = await _db.collection('sales').where('status', isEqualTo: 'pending_deduction').get();
      final batchDelete = _db.batch();
      for (var doc in salesQuery.docs) batchDelete.delete(doc.reference);
      await batchDelete.commit();
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _applyStockDeduction() async {
    setState(() => _isProcessing = true);
    try {
      final salesQuery = await _db.collection('sales').where('status', isEqualTo: 'pending_deduction').get();
      if (salesQuery.docs.isEmpty) return;
      final batchWrite = _db.batch();
      final now = Timestamp.now();

      for (var saleDoc in salesQuery.docs) {
        final saleData = saleDoc.data() as Map<String, dynamic>;
        final productId = saleData['productID'];
        int qtyToDeduct = saleData['quantitySold'];

        final batchesQuery = await _db.collection('batches')
            .where('productId', isEqualTo: productId)
            .where('currentQuantity', isGreaterThan: 0)
            .orderBy('currentQuantity')
            .orderBy('expiryDate', descending: false)
            .get();

        for (var bDoc in batchesQuery.docs) {
          if (qtyToDeduct <= 0) break;
          int batchQty = bDoc['currentQuantity'];
          int take = (batchQty >= qtyToDeduct) ? qtyToDeduct : batchQty;
          batchWrite.update(bDoc.reference, {'currentQuantity': FieldValue.increment(-take), 'updatedAt': now});
          qtyToDeduct -= take;

          batchWrite.set(_db.collection('stockMovements').doc(), {
            'productId': productId, 'productName': saleData['snapshotName'], 'movementType': 'OUT_SALE',
            'quantity': -take, 'batchId': bDoc.id, 'batchNumber': bDoc.data()['batchNumber'],
            'userId': _auth.currentUser?.uid, 'movementDate': now, 'referenceId': saleDoc.id,
          });
        }
        batchWrite.update(_db.collection('products').doc(productId), {'currentStock': FieldValue.increment(-saleData['quantitySold']), 'updatedAt': now});
        batchWrite.update(saleDoc.reference, {'status': 'completed'});
      }
      await batchWrite.commit();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock applied!"), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Apply Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _rowSummary(String l, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 13)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
  );
}