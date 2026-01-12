import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';

// Pastikan path import ini betul ikut struktur folder anda
import '../Features_app/barcode_scanner_page.dart';

// --- [GLOBAL CART MANAGER] ---
// Ini memastikan data cart manual KEKAL walaupun user keluar masuk page
class StockOutCartManager {
  static final StockOutCartManager _instance = StockOutCartManager._internal();
  factory StockOutCartManager() => _instance;
  StockOutCartManager._internal();

  List<StockOutItem> items = [];

  void addItem(StockOutItem newItem) {
    // Logic Gabung (Merge): Kalau batch sama, tambah quantity je
    int index = items.indexWhere((i) => i.batchId == newItem.batchId);
    if (index != -1) {
      var old = items[index];
      items[index] = StockOutItem(
          productId: old.productId,
          productName: old.productName,
          imageUrl: old.imageUrl,
          quantity: old.quantity + newItem.quantity,
          batchId: old.batchId,
          batchNumber: old.batchNumber
      );
    } else {
      items.add(newItem);
    }
  }

  void removeItem(int index) {
    items.removeAt(index);
  }

  void clearCart() {
    items.clear();
  }

  // Helper untuk check qty yang dah ada dalam cart (untuk validasi)
  int getQuantityForBatch(String batchId) {
    return items
        .where((i) => i.batchId == batchId)
        .fold(0, (sum, i) => sum + i.quantity);
  }
}

class StockOutPage extends StatefulWidget {
  const StockOutPage({super.key});

  @override
  State<StockOutPage> createState() => _StockOutPageState();
}

class _StockOutPageState extends State<StockOutPage> {
  final Color mainBlue = const Color(0xFF1E3A8A); // Indigo Premium
  final Color scaffoldBg = const Color(0xFFF8FAFF);
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Panggil Cart Manager (Global)
  final StockOutCartManager _cartManager = StockOutCartManager();

  int _currentSubTab = 0;
  bool _autoDeduct = true;
  bool _isProcessing = false;

  DateTime _selectedDate = DateTime.now();
  String _selectedReason = 'damaged';
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // --- CUSTOM DIALOG PREMIUM ---
  void _showAlert(String title, String message, {bool isError = false, bool isWarning = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isError
                      ? Colors.red.withOpacity(0.1)
                      : (isWarning ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_outline_rounded : (isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded),
                  color: isError ? Colors.red : (isWarning ? Colors.orange : Colors.green),
                  size: 45,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isError ? Colors.red : (isWarning ? Colors.orange : mainBlue),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Got it!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
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
            _subTabBtn('Sold', 0),
            _subTabBtn('Others', 1),
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

  // ======================== TAB 0: SOLD (PENDING SALES) ========================

  Widget _buildSoldTab() {
    return Column(
      children: [
        _buildAutoDeductToggle(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('pending_sales').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState("No outstanding sales.");

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
            Text("Preview remaining stock after sale", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
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
    // [FIX] Ambil list dari Manager supaya tak hilang bila refresh
    List<StockOutItem> items = _cartManager.items;

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

                if (items.isEmpty)
                  _buildEmptyState("No items for removal.")
                else
                  ...items.asMap().entries.map((entry) => _buildCartItemCard(entry.key, entry.value)),

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
        IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
            // [FIX] Remove dari Global Manager dan refresh UI
            onPressed: () => setState(() {
              _cartManager.removeItem(index);
            })
        ),
      ]),
    );
  }

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
    bool hasItems = _cartManager.items.isNotEmpty;

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
                onPressed: hasItems ? _saveOthersStockOutToFirebase : null,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('CONFIRM REMOVAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))
            )
        ),
      ])),
    );
  }

  // ======================== SHARED LOGIC ========================

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

  // ======================== [UPDATED] CLEAR PENDING SALES & UNLOCK ========================
  Future<void> _clearPendingSales() async {
    bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Clear List & Unlock?"),
          content: const Text("This will discard all pending entries and UNLOCK daily sales for staff. Confirm?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, Clear")),
          ],
        )) ?? false;

    if (!confirm) return;
    setState(() => _isProcessing = true);

    try {
      final batch = _db.batch();

      // 1. Delete all pending sales (Macam biasa)
      final salesQ = await _db.collection('pending_sales').get();
      for (var doc in salesQ.docs) {
        batch.delete(doc.reference);
      }

      // 2. [TAMBAHAN PENTING] Delete LOCK LOG hari ini
      // Ini akan membolehkan DailySalesPage dibuka semula
      final String todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final logRef = _db.collection('daily_sales_log').doc(todayDocId);
      batch.delete(logRef);

      await batch.commit();

      if (mounted) {
        _showAlert("Cleared & Unlocked", "Pending list cleared. Daily Sales input is now UNLOCKED for all staff.", isError: false);
      }
    } catch (e) {
      _showAlert("Error", e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ======================== CORE LOGIC: APPLY & DEDUCT (SALES) ========================

  Future<void> _applyStockDeduction() async {
    setState(() => _isProcessing = true);
    try {
      final pendingQuery = await _db.collection('pending_sales').get();
      if (pendingQuery.docs.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      final batchWrite = _db.batch();
      final now = Timestamp.now();
      List<String> errors = [];

      final currentUser = FirebaseAuth.instance.currentUser;
      final String userId = currentUser?.uid ?? 'Staff';

      for (var saleDoc in pendingQuery.docs) {
        final saleData = saleDoc.data() as Map<String, dynamic>;
        final productId = saleData['productID'];
        final productName = saleData['snapshotName'];
        final double totalAmount = (saleData['totalAmount'] is int)
            ? (saleData['totalAmount'] as int).toDouble()
            : (saleData['totalAmount'] ?? 0.0);
        int qtyToDeduct = saleData['quantitySold'];

        // 1. FEFO Logic
        final batchesQ = await _db.collection('batches')
            .where('productId', isEqualTo: productId)
            .where('currentQuantity', isGreaterThan: 0)
            .orderBy('expiryDate')
            .get();

        int totalAvailable = batchesQ.docs.fold(0, (sum, b) => sum + (b['currentQuantity'] as int));

        if (totalAvailable < qtyToDeduct) {
          errors.add("$productName (Need: $qtyToDeduct, Have: $totalAvailable)");
          continue;
        }

        // 2. Tolak stok dari batch
        int remainingToDeduct = qtyToDeduct;
        for (var bDoc in batchesQ.docs) {
          if (remainingToDeduct <= 0) break;
          int bQty = bDoc['currentQuantity'];
          int take = (bQty >= remainingToDeduct) ? remainingToDeduct : bQty;

          batchWrite.update(bDoc.reference, {
            'currentQuantity': FieldValue.increment(-take),
            'updatedAt': now
          });
          remainingToDeduct -= take;
        }

        // 3. Update Master Product
        batchWrite.update(_db.collection('products').doc(productId), {
          'currentStock': FieldValue.increment(-qtyToDeduct),
          'updatedAt': now
        });

        // 4. REKOD JUALAN
        final salesRef = _db.collection('sales').doc();
        batchWrite.set(salesRef, {
          'salesID': salesRef.id,
          'productID': productId,
          'snapshotName': productName,
          'quantitySold': qtyToDeduct,
          'totalAmount': totalAmount,
          'saleDate': now,
          'status': 'completed',
          'userID': userId,
          'remarks': 'Auto-deducted from pending list',
        });

        // 5. Rekod Stock Movement
        final movementRef = _db.collection('stockMovements').doc();
        batchWrite.set(movementRef, {
          'movementId': movementRef.id,
          'productId': productId,
          'productName': productName,
          'quantity': -qtyToDeduct,
          'type': 'Sold',
          'reason': 'Sales Order Completed',
          'timestamp': now,
          'user': userId
        });

        batchWrite.delete(saleDoc.reference);
      }

      if (errors.isNotEmpty) {
        if (mounted) {
          String errorMessage = "The following items do not have enough stock:\n\n${errors.join('\n')}";
          _showAlert("Insufficient Stock", errorMessage, isError: true);
        }
      } else {
        await batchWrite.commit();
        if (mounted) {
          _showAlert("Sales Recorded", "Sales confirmed and recorded into history.", isError: false);
        }
      }
    } catch (e) {
      _showAlert("System Error", e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ======================== CORE LOGIC: MANUAL REMOVAL ========================

  Future<void> _saveOthersStockOutToFirebase() async {
    setState(() => _isProcessing = true);
    try {
      final batch = _db.batch();
      final now = Timestamp.now();

      // [FIX] Loop items dari Manager
      for (var item in _cartManager.items) {
        batch.update(_db.collection('batches').doc(item.batchId), {'currentQuantity': FieldValue.increment(-item.quantity), 'updatedAt': now});
        batch.update(_db.collection('products').doc(item.productId), {'currentStock': FieldValue.increment(-item.quantity), 'updatedAt': now});
        final movementRef = _db.collection('stockMovements').doc();
        batch.set(movementRef, {'movementId': movementRef.id, 'productId': item.productId, 'productName': item.productName, 'quantity': -item.quantity, 'type': 'Manual Adjustment', 'reason': _selectedReason.toUpperCase(), 'notes': _notesController.text.trim(), 'timestamp': now, 'user': 'Staff'});
      }
      await batch.commit();

      setState(() {
        _cartManager.clearCart(); // Clear lepas save
        _notesController.clear();
        _isProcessing = false;
      });
      _showAlert("Manual Removal Success", "Stock adjustment for manual reasons has been recorded.", isError: false);
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      _showAlert("System Error", e.toString(), isError: true);
    }
  }

  void _showProductSelectionModal() {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (context) => _ProductSelector(onProductSelected: (product) => _showQuantityAndBatchDialog(product)));
  }

  // --- [KEMASKINI: LOGIC VALIDASI & MERGE & ERROR TEXT] ---
  void _showQuantityAndBatchDialog(DocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    final qtyController = TextEditingController(text: '1');

    String? selectedBatchId;
    String selectedBatchNum = '';
    int dbBatchStock = 0;
    String? inputErrorText;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setModalState) {

              // [FIX] Check qty dalam Manager (Bukan local list)
              int existingInCart = 0;
              if (selectedBatchId != null) {
                existingInCart = _cartManager.getQuantityForBatch(selectedBatchId!);
              }

              int availableToAdd = dbBatchStock - existingInCart;

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text("Remove: ${data['productName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('batches')
                            .where('productId', isEqualTo: productDoc.id)
                            .where('currentQuantity', isGreaterThan: 0)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const LinearProgressIndicator();
                          final batches = snapshot.data!.docs;

                          if (batches.isEmpty) return const Text("OUT OF STOCK IN BATCHES", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));

                          return DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedBatchId,
                            hint: const Text("Choose Batch"),
                            items: batches.map((b) => DropdownMenuItem(
                                value: b.id,
                                child: Text("${b['batchNumber']} (Bal: ${b['currentQuantity']})"),
                                onTap: () {
                                  selectedBatchNum = b['batchNumber'];
                                  dbBatchStock = b['currentQuantity'];
                                  setModalState(() => inputErrorText = null);
                                }
                            )).toList(),
                            onChanged: (v) => setModalState(() => selectedBatchId = v),
                            decoration: InputDecoration(filled: true, fillColor: scaffoldBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                          );
                        },
                      ),
                      const SizedBox(height: 15),

                      TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            if (inputErrorText != null) {
                              setModalState(() => inputErrorText = null);
                            }
                          },
                          decoration: InputDecoration(
                              labelText: "Quantity",
                              // [FIX] Error Text akan muncul di sini (Tak tertutup dialog)
                              errorText: inputErrorText,
                              errorMaxLines: 3,

                              helperText: selectedBatchId != null
                                  ? "Database: $dbBatchStock | In Cart: $existingInCart"
                                  : null,
                              helperStyle: TextStyle(
                                  color: availableToAdd == 0 ? Colors.red : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11
                              ),
                              border: const OutlineInputBorder()
                          )
                      ),
                    ]
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: mainBlue),
                      onPressed: selectedBatchId == null ? null : () {
                        int inputQty = int.tryParse(qtyController.text) ?? 0;

                        if (inputQty <= 0) {
                          setModalState(() => inputErrorText = "Enter valid quantity");
                          return;
                        }

                        // [FIX] Check limit menggunakan Manager
                        int currentCartQty = _cartManager.getQuantityForBatch(selectedBatchId!);

                        if ((inputQty + currentCartQty) > dbBatchStock) {
                          setModalState(() {
                            inputErrorText = "Over limit! Max add: ${dbBatchStock - currentCartQty}";
                          });
                          return;
                        }

                        // [FIX] Tambah ke Manager & Refresh UI
                        setState(() {
                          _cartManager.addItem(StockOutItem(
                              productId: productDoc.id,
                              productName: data['productName'],
                              imageUrl: data['imageUrl'],
                              quantity: inputQty,
                              batchId: selectedBatchId!,
                              batchNumber: selectedBatchNum
                          ));
                        });

                        Navigator.pop(ctx);

                        // [FIX] Tunjuk feedback item dah masuk list
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Added ${data['productName']} to list"),
                                duration: const Duration(milliseconds: 800),
                                behavior: SnackBarBehavior.floating
                            )
                        );
                      },
                      child: const Text("Add to List", style: TextStyle(color: Colors.white))
                  ),
                ],
              );
            }
        )
    );
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

  Widget _buildProductImage(String? url, {double size = 55}) {
    if (url == null || url.isEmpty) {
      return Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.1), width: 1.5)), child: Center(child: Icon(Icons.inventory_2_rounded, color: const Color(0xFF1E3A8A).withOpacity(0.3), size: size * 0.5)));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover, placeholder: (_, __) => Container(width: size, height: size, color: Colors.grey[100])));
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