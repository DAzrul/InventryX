import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart'; // [PENTING] Tambah ini
import '../Features_app/barcode_scanner_page.dart';
import 'dart:math';

class StockOutPage extends StatefulWidget {
  const StockOutPage({super.key});

  @override
  State<StockOutPage> createState() => _StockOutPageState();
}

class _StockOutPageState extends State<StockOutPage> {
  final Color mainBlue = const Color(0xFF1E3A8A); // Indigo Premium
  final Color scaffoldBg = const Color(0xFFF8FAFF);
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _currentSubTab = 0;
  bool _autoDeduct = true;
  bool _isProcessing = false;

  DateTime _selectedDate = DateTime.now();
  String _selectedReason = 'damaged';
  final TextEditingController _notesController = TextEditingController();
  List<StockOutItem> _cartItems = [];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showAlert(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: isError ? Colors.red : mainBlue)),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Outgoing Stock',
            style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: Column(
        children: [
          _buildSubTabSwitcher(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentSubTab == 0 ? _buildSoldTab() : _buildOthersTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabSwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            _subTabBtn('Sales / Sold', 0),
            _subTabBtn('Others / Manual', 1),
          ],
        ),
      ),
    );
  }

  Widget _subTabBtn(String label, int index) {
    bool sel = _currentSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentSubTab = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: sel ? mainBlue : Colors.grey.shade500,
                    fontWeight: FontWeight.w800,
                    fontSize: 13
                )
            ),
          ),
        ),
      ),
    );
  }

  // ======================== TAB 0: SOLD ========================

  Widget _buildSoldTab() {
    return Column(
      children: [
        _buildAutoDeductToggle(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('sales').where('status', isEqualTo: 'pending_deduction').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState("Tiada jualan tertunggak.");

              final salesDocs = snapshot.data!.docs;
              return FutureBuilder<Map<String, int>>(
                future: _calculateTotals(salesDocs),
                builder: (context, totalSnapshot) {
                  int tPrev = totalSnapshot.data?['prev'] ?? 0;
                  int tSold = totalSnapshot.data?['sold'] ?? 0;
                  int tAutoResult = _autoDeduct ? max(0, tPrev - tSold) : tPrev;

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const BouncingScrollPhysics(),
                          itemCount: salesDocs.length,
                          itemBuilder: (context, index) => _buildSaleDeductionCard(salesDocs[index].data() as Map<String, dynamic>),
                        ),
                      ),
                      _buildApplyFooter(tPrev, tSold, tAutoResult),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAutoDeductToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mainBlue.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Apply Auto-Deduction", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            Text("Preview baki stok selepas jualan", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
          ]),
          Transform.scale(
            scale: 0.8,
            child: Switch(
                value: _autoDeduct,
                activeColor: Colors.white,
                activeTrackColor: mainBlue,
                onChanged: (v) => setState(() => _autoDeduct = v)
            ),
          ),
        ],
      ),
    );
  }

  // ======================== TAB 1: OTHERS ========================

  Widget _buildOthersTab() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOthersHeaderForm(),
                const SizedBox(height: 30),
                const Text("Items to Remove", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                _buildAddProductButton(),
                const SizedBox(height: 16),
                if (_cartItems.isEmpty)
                  _buildEmptyState("No items for removal.")
                else
                  ..._cartItems.asMap().entries.map((entry) => _buildCartItemCard(entry.key, entry.value)),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
        _buildOthersBottomAction(),
      ],
    );
  }

  Widget _buildOthersHeaderForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)]
      ),
      child: Column(children: [
        InkWell(
          onTap: () async {
            DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2030));
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_today_rounded, color: Colors.blue, size: 18)),
            const SizedBox(width: 15),
            Text(DateFormat('dd MMMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ]),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
        DropdownButtonFormField<String>(
          value: _selectedReason,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: ['damaged', 'expired', 'returned', 'theft', 'adjustment', 'others'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
          onChanged: (val) => setState(() => _selectedReason = val!),
          decoration: InputDecoration(
            labelText: 'Reason',
            labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w700),
            filled: true, fillColor: scaffoldBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
      ]),
    );
  }

  Widget _buildAddProductButton() {
    return InkWell(
      onTap: _showProductSelectionModal,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: mainBlue.withOpacity(0.2), width: 1.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: mainBlue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_circle_outline_rounded, color: mainBlue, size: 22),
          const SizedBox(width: 10),
          Text("Add Product", style: TextStyle(color: mainBlue, fontWeight: FontWeight.w800, fontSize: 14))
        ]),
      ),
    );
  }

  // --- [KEMASKINI UTAMA] UI CART ITEM YG SERAGAM ---
  Widget _buildCartItemCard(int index, StockOutItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100)
      ),
      child: Row(children: [
        // [FIX] Guna method gambar yang seragam (Saiz 55)
        _buildProductImage(item.imageUrl, size: 55),

        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          Text("Batch: ${item.batchNumber}", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600))
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Text("-${item.quantity}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 15)),
        ),
        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20), onPressed: () => setState(() => _cartItems.removeAt(index))),
      ]),
    );
  }

  // --- [UTAMA] WIDGET GAMBAR SERAGAM ---
  Widget _buildProductImage(String? url, {double size = 55}) {
    if (url == null || url.isEmpty) {
      return _buildPlaceholder(size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildPlaceholder(size),
        errorWidget: (_, __, ___) => _buildPlaceholder(size),
      ),
    );
  }

  // --- [UTAMA] WIDGET PLACEHOLDER ---
  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: mainBlue.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: mainBlue.withOpacity(0.3),
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildOthersBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 15, 24, 30),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]
      ),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Global Remarks...',
              prefixIcon: const Icon(Icons.edit_note_rounded),
              filled: true, fillColor: scaffoldBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            )
        ),
        const SizedBox(height: 20),
        SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                onPressed: _cartItems.isEmpty ? null : _saveOthersStockOutToFirebase,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('CONFIRM REMOVAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))
            )
        ),
      ])),
    );
  }

  // ======================== SHARED LOGIC (DO NOT MODIFY) ========================

  Future<Map<String, int>> _calculateTotals(List<QueryDocumentSnapshot> docs) async {
    int prevTotal = 0, soldTotal = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      soldTotal += (data['quantitySold'] as int? ?? 0);
      var pDoc = await _db.collection('products').doc(data['productID']).get();
      if (pDoc.exists) prevTotal += (pDoc.data()?['currentStock'] as int? ?? 0);
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

        bool isInsufficient = prevStock < soldQty;
        final int balanceDisplay = _autoDeduct ? max(0, prevStock - soldQty) : prevStock;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              border: Border.all(color: isInsufficient && _autoDeduct ? Colors.red.withOpacity(0.3) : Colors.grey.shade50, width: isInsufficient ? 1.5 : 1)
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(sale['snapshotName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15), overflow: TextOverflow.ellipsis)),
                if (isInsufficient)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: const Text("INSUFFICIENT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  )
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _statColumn("Previous Stock", prevStock.toString(), Colors.grey.shade600),
              _statColumn("Units Sold", "-$soldQty", isInsufficient ? Colors.red : Colors.orange.shade800),
              _statColumn("Est. Balance", balanceDisplay.toString(), _autoDeduct ? mainBlue : Colors.grey.shade300),
            ])
          ]),
        );
      },
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color))
    ]);
  }

  Widget _buildApplyFooter(int tPrev, int tSold, int tAutoResult) {
    final String projectedDisplay = _autoDeduct ? "$tAutoResult" : "$tPrev";
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 35),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]
      ),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _rowSummary("Total Prev Stock", tPrev.toString()),
        _rowSummary("Total Units Sold", tSold.toString()),
        _rowSummary("Total Est. Balance", projectedDisplay),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(
              onPressed: _clearPendingSales,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: const BorderSide(color: Colors.redAccent),
              ),
              child: const Text("Cancel All", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800))
          )),
          const SizedBox(width: 15),
          Expanded(flex: 2, child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: mainBlue,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isProcessing ? null : _applyStockDeduction,
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text("APPLY CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))
          )),
        ])
      ])),
    );
  }

  Future<void> _clearPendingSales() async {
    bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Clear List?"),
          content: const Text("Do you want to discard all pending entries?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, Clear")),
          ],
        )) ?? false;
    if (!confirm) return;
    setState(() => _isProcessing = true);
    final salesQ = await _db.collection('sales').where('status', isEqualTo: 'pending_deduction').get();
    final batch = _db.batch();
    for (var doc in salesQ.docs) batch.delete(doc.reference);
    await batch.commit();
    setState(() => _isProcessing = false);
  }

  // ======================== CORE LOGIC (DO NOT MODIFY) ========================

  Future<void> _applyStockDeduction() async {
    setState(() => _isProcessing = true);
    try {
      final salesQuery = await _db.collection('sales').where('status', isEqualTo: 'pending_deduction').get();
      if (salesQuery.docs.isEmpty) return;

      List<String> insufficientItems = [];
      for (var saleDoc in salesQuery.docs) {
        final saleData = saleDoc.data() as Map<String, dynamic>;
        final productId = saleData['productID'];
        final soldQty = saleData['quantitySold'] as int;
        final prodDoc = await _db.collection('products').doc(productId).get();
        final currentStock = (prodDoc.data()?['currentStock'] ?? 0) as int;
        if (currentStock < soldQty) {
          insufficientItems.add("${saleData['snapshotName']} (Need $soldQty, Have $currentStock)");
        }
      }

      if (insufficientItems.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text("Stock Error")]),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Deduction failed due to insufficient stock:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...insufficientItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text("• $item", style: const TextStyle(fontSize: 13, color: Colors.red)),
                    )),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: mainBlue),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("I'll Fix It", style: TextStyle(color: Colors.white))
                ),
              ],
            ),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      final batchWrite = _db.batch();
      final now = Timestamp.now();
      for (var saleDoc in salesQuery.docs) {
        final saleData = saleDoc.data() as Map<String, dynamic>;
        final productId = saleData['productID'];
        final productName = saleData['snapshotName'];
        int qtyToDeduct = saleData['quantitySold'];

        final batchesQ = await _db.collection('batches').where('productId', isEqualTo: productId).where('currentQuantity', isGreaterThan: 0).orderBy('currentQuantity').orderBy('expiryDate').get();

        int actuallyDeducted = 0;
        for (var bDoc in batchesQ.docs) {
          if (qtyToDeduct <= 0) break;
          int bQty = bDoc['currentQuantity'];
          int take = (bQty >= qtyToDeduct) ? qtyToDeduct : bQty;
          batchWrite.update(bDoc.reference, {'currentQuantity': FieldValue.increment(-take), 'updatedAt': now});
          qtyToDeduct -= take; actuallyDeducted += take;
        }

        batchWrite.update(_db.collection('products').doc(productId), {'currentStock': FieldValue.increment(-actuallyDeducted), 'updatedAt': now});
        final movementRef = _db.collection('stockMovements').doc();
        batchWrite.set(movementRef, {'movementId': movementRef.id, 'productId': productId, 'productName': productName, 'quantity': -actuallyDeducted, 'type': 'Sold', 'reason': 'Customer Purchase', 'timestamp': now, 'user': 'Staff'});
        batchWrite.update(saleDoc.reference, {'status': 'completed'});
      }
      await batchWrite.commit();
      if (mounted) _showAlert("Success", "All stock has been successfully deducted and recorded.");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveOthersStockOutToFirebase() async {
    setState(() => _isProcessing = true);
    try {
      final batch = _db.batch();
      final now = Timestamp.now();
      for (var item in _cartItems) {
        batch.update(_db.collection('batches').doc(item.batchId), {'currentQuantity': FieldValue.increment(-item.quantity), 'updatedAt': now});
        batch.update(_db.collection('products').doc(item.productId), {'currentStock': FieldValue.increment(-item.quantity), 'updatedAt': now});
        final movementRef = _db.collection('stockMovements').doc();
        batch.set(movementRef, {'movementId': movementRef.id, 'productId': item.productId, 'productName': item.productName, 'quantity': -item.quantity, 'type': 'Manual Adjustment', 'reason': _selectedReason.toUpperCase(), 'notes': _notesController.text.trim(), 'timestamp': now, 'user': 'Staff'});
      }
      await batch.commit();
      setState(() { _cartItems.clear(); _notesController.clear(); _isProcessing = false; });
      _showAlert("Success", "Manual removal has been recorded in stock movements.");
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showProductSelectionModal() {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (context) => _ProductSelector(onProductSelected: (product) => _showQuantityAndBatchDialog(product)));
  }

  void _showQuantityAndBatchDialog(DocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    final qtyController = TextEditingController(text: '1');
    String? selectedBatchId; String selectedBatchNum = ''; int maxQuantity = 0;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Remove: ${data['productName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('batches').where('productId', isEqualTo: productDoc.id).where('currentQuantity', isGreaterThan: 0).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final batches = snapshot.data!.docs;
              if (batches.isEmpty) return const Text("TIADA STOK DLM BATCH", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
              return DropdownButtonFormField<String>(
                isExpanded: true, value: selectedBatchId, hint: const Text("Choose Batch"),
                items: batches.map((b) => DropdownMenuItem(value: b.id, child: Text("${b['batchNumber']} (Bal: ${b['currentQuantity']})"), onTap: () { selectedBatchNum = b['batchNumber']; maxQuantity = b['currentQuantity']; })).toList(),
                onChanged: (v) => setModalState(() => selectedBatchId = v),
                decoration: InputDecoration(filled: true, fillColor: scaffoldBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              );
            },
          ),
          const SizedBox(height: 15),
          TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Quantity", helperText: selectedBatchId != null ? "Available: $maxQuantity" : null, border: const OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: mainBlue), onPressed: selectedBatchId == null ? null : () {
            int q = int.tryParse(qtyController.text) ?? 0;
            if (q <= 0 || q > maxQuantity) return;
            setState(() => _cartItems.add(StockOutItem(productId: productDoc.id, productName: data['productName'], imageUrl: data['imageUrl'], quantity: q, batchId: selectedBatchId!, batchNumber: selectedBatchNum)));
            Navigator.pop(ctx); Navigator.pop(context);
          }, child: const Text("Add to List", style: TextStyle(color: Colors.white))),
        ],
      );
    }));
  }

  Widget _rowSummary(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 13)), Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))]));
  Widget _buildEmptyState(String msg) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade200), const SizedBox(height: 10), Text(msg, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500))]));
}

class _ProductSelector extends StatefulWidget {
  final Function(DocumentSnapshot) onProductSelected;
  const _ProductSelector({required this.onProductSelected});
  @override
  State<_ProductSelector> createState() => _ProductSelectorState();
}

class _ProductSelectorState extends State<_ProductSelector> {
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // --- [KEMASKINI UTAMA] Helper Method untuk Gambar Seragam ---
  Widget _buildProductImage(String? url, {double size = 55}) {
    if (url == null || url.isEmpty) {
      return _buildPlaceholder(size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildPlaceholder(size),
        errorWidget: (_, __, ___) => _buildPlaceholder(size),
      ),
    );
  }

  // --- Helper Method untuk Placeholder ---
  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF1E3A8A).withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: const Color(0xFF1E3A8A).withOpacity(0.3),
          size: size * 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TextField(controller: _searchCtrl, onChanged: (v) => setState(() => _query = v.toLowerCase()), decoration: InputDecoration(hintText: "Search products in stock...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFFF8FAFF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))),
          const SizedBox(width: 10),
          GestureDetector(onTap: () async {
            final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
            if (code != null) setState(() { _searchCtrl.text = code; _query = code.toLowerCase(); });
          }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E3A8A), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.qr_code_scanner, color: Colors.white))),
        ]),
        const SizedBox(height: 20),
        Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').where('currentStock', isGreaterThan: 0).snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs.where((d) => d['productName'].toString().toLowerCase().contains(_query) || (d['barcodeNo'] ?? '').toString().contains(_query)).toList();
              return ListView.builder(itemCount: docs.length, itemBuilder: (ctx, i) {
                final prod = docs[i].data() as Map<String, dynamic>;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  // [FIX] Guna method gambar yang seragam
                  leading: _buildProductImage(prod['imageUrl'], size: 55),
                  title: Text(prod['productName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Stock: ${prod['currentStock']}", style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.add_circle_rounded, color: Color(0xFF1E3A8A)),
                  onTap: () => widget.onProductSelected(docs[i]),
                );
              });
            }
        ))
      ]),
    );
  }
}

class StockOutItem {
  final String productId, productName, batchId, batchNumber;
  final String? imageUrl;
  final int quantity;
  StockOutItem({required this.productId, required this.productName, this.imageUrl, required this.quantity, required this.batchId, required this.batchNumber});
}