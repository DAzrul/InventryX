import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Features_app/barcode_scanner_page.dart';

class AddIncomingStockPage extends StatefulWidget {
  final String username;
  const AddIncomingStockPage({super.key, required this.username});

  @override
  State<AddIncomingStockPage> createState() => _AddIncomingStockPageState();
}

class _AddIncomingStockPageState extends State<AddIncomingStockPage> {
  final Color primaryBlue = const Color(0xFF1E3A8A);
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _searchQuery = '';

  String? selectedSupplierName;
  String? selectedSupplierId;
  List<StockItem> batchItems = [];

  int get totalQuantity => batchItems.fold(0, (sum, item) => sum + item.totalUnits);
  bool get hasQuantity => batchItems.any((item) => item.quantity > 0);

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Incoming Stock',
            style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("1. Supplier Information", Icons.local_shipping_rounded),
                  const SizedBox(height: 12),
                  _supplierDropdown(),
                  const SizedBox(height: 30),

                  _buildSectionHeader("2. Add Products", Icons.add_business_rounded),
                  const SizedBox(height: 12),
                  _findProductField(),
                  const SizedBox(height: 30),

                  _buildSectionHeader("3. Batch - Stock In (${batchItems.length})", Icons.inventory_rounded),
                  const SizedBox(height: 12),
                  _batchList(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _bottomSection(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryBlue),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _supplierDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('supplier').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final suppliers = snapshot.data!.docs;
          return DropdownButtonFormField<String>(
            value: selectedSupplierName,
            isExpanded: true,
            hint: const Text('Choose active supplier', style: TextStyle(fontSize: 14)),
            items: suppliers.map<DropdownMenuItem<String>>((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return DropdownMenuItem<String>(
                value: data['supplierName'],
                child: Text(data['supplierName'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                selectedSupplierName = val;
                if (val != null) {
                  final doc = suppliers.firstWhere((d) => d['supplierName'] == val);
                  selectedSupplierId = doc.id;
                }
              });
            },
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.business_center_rounded, color: primaryBlue, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            ),
          );
        },
      ),
    );
  }

  Widget _findProductField() {
    bool isLocked = selectedSupplierName == null;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: isLocked ? () => _showError('Please choose the supplier first!') : _showProductDialog,
            child: Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isLocked ? Colors.transparent : primaryBlue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: isLocked ? Colors.grey : primaryBlue, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    isLocked ? 'Select supplier first' : 'Search products...',
                    style: TextStyle(color: isLocked ? Colors.grey : Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: isLocked ? null : _scanBarcode,
          child: Container(
            height: 55, width: 55,
            decoration: BoxDecoration(
              gradient: isLocked ? null : LinearGradient(colors: [primaryBlue, primaryBlue.withOpacity(0.8)]),
              color: isLocked ? Colors.grey.shade200 : null,
              borderRadius: BorderRadius.circular(18),
              boxShadow: isLocked ? null : [BoxShadow(color: primaryBlue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(Icons.qr_code_scanner_rounded, color: isLocked ? Colors.grey : Colors.white),
          ),
        ),
      ],
    );
  }

  void _showProductDialog() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Text("Products: $selectedSupplierName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: (v) => setModalState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search item name...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true, fillColor: const Color(0xFFF8FAFF),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('products').where('supplier', isEqualTo: selectedSupplierName).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final list = snapshot.data!.docs.where((d) {
                      final name = d['productName'].toString().toLowerCase();
                      return name.contains(_searchQuery);
                    }).toList();
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final d = list[i].data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
                            leading: _buildProductImage(d['imageUrl'], size: 55),
                            title: Text(d['productName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('Current Stock: ${d['currentStock']}', style: const TextStyle(fontSize: 12)),
                            trailing: Icon(Icons.add_circle_rounded, color: primaryBlue),
                            onTap: () {
                              _addBatchItem(
                                list[i].id,
                                d['productName'],
                                d['barcodeNo'].toString(),
                                d['imageUrl'],
                                d['unitsPerCarton'] ?? 1,
                              );
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(String? url, {double size = 55}) {
    if (url == null || url.isEmpty) return _buildPlaceholder(size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: CachedNetworkImage(
        imageUrl: url, width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => _buildPlaceholder(size),
        errorWidget: (_, __, ___) => _buildPlaceholder(size),
      ),
    );
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryBlue.withOpacity(0.1), width: 1.5)),
      child: Center(child: Icon(Icons.inventory_2_rounded, color: primaryBlue.withOpacity(0.3), size: size * 0.5)),
    );
  }

  void _addBatchItem(String pid, String? name, String bc, String? url, int unitsPerCarton) {
    setState(() {
      batchItems.add(StockItem(
        productId: pid,
        productName: name ?? 'Unknown',
        barcodeNo: bc,
        imageUrl: url,
        supplierName: selectedSupplierName!,
        supplierId: selectedSupplierId!,
        quantity: 0,
        unitsPerCarton: unitsPerCarton,
        expiryDate: DateTime.now().add(const Duration(days: 180)),
      ));
    });
  }

  Widget _batchList() {
    if (batchItems.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(children: [Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey.shade300), const SizedBox(height: 10), Text('No batches added yet', style: TextStyle(color: Colors.grey.shade400))])));
    return Column(
      children: batchItems.asMap().entries.map((entry) {
        final i = entry.key; final item = entry.value;
        final TextEditingController _qtyController = TextEditingController(text: item.quantity.toString());
        _qtyController.selection = TextSelection.fromPosition(TextPosition(offset: _qtyController.text.length));

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align to start for labels
            children: [
              Row(
                children: [
                  _buildProductImage(item.imageUrl, size: 55),
                  const SizedBox(width: 15),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    // Displaying Barcode/SN
                    Text("SN: ${item.barcodeNo}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Text("From: ${item.supplierName}", style: TextStyle(fontSize: 11, color: primaryBlue, fontWeight: FontWeight.bold)),
                  ])),
                  IconButton(icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20), onPressed: () => setState(() => batchItems.removeAt(i))),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

              // Added labels for Quantity and Expiry Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Quantity", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                  Text("Expiry Date", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  _qtyBtn(Icons.remove_rounded, () => setState(() { if(item.quantity > 0) item.quantity--; })),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                      onChanged: (v) {
                        int? n = int.tryParse(v);
                        if(n != null) { item.quantity = n; setState(() {}); }
                      },
                    ),
                  ),
                  _qtyBtn(Icons.add_rounded, () => setState(() { item.quantity++; })),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: item.expiryDate, firstDate: DateTime.now(), lastDate: DateTime(2035));
                      if(d != null) setState(() => item.expiryDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.event_available_rounded, size: 14, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(DateFormat('dd/MM/yyyy').format(item.expiryDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${item.quantity} x ${item.unitsPerCarton} = ${item.totalUnits} units",
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
        child: Icon(icon, size: 18, color: primaryBlue),
      ),
    );
  }

  Widget _bottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'General notes...',
              prefixIcon: const Icon(Icons.note_alt_rounded),
              filled: true, fillColor: const Color(0xFFF8FAFF),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Total Quantity", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                Text("$totalQuantity Units", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ]),
              ElevatedButton(
                onPressed: hasQuantity ? _saveStockToFirebase : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Confirm Stock", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  // --- [UPDATED LOGIC] Unified stockId for stockIn and batches ---
  Future<void> _saveStockToFirebase() async {
    final user = _auth.currentUser;
    if (user == null || batchItems.isEmpty) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final batchWrite = _db.batch();
      final now = Timestamp.now();

      // 1. Generate a formatted Unified stockId (SI-YYYYMMDD-SUFFIX)
      String datePart = DateFormat('yyyyMMdd').format(DateTime.now());
      // Take the last 3 digits of the timestamp for a unique suffix
      String suffix = DateTime.now().microsecondsSinceEpoch.toString().substring(10);
      String sessionStockId = "SI-$datePart-$suffix";

      Map<String, List<StockItem>> grouped = {};
      for (var item in batchItems) {
        if (item.quantity <= 0) continue;
        grouped.putIfAbsent(item.supplierId, () => []).add(item);
      }

      for (var entry in grouped.entries) {
        final sId = entry.key;
        final items = entry.value;
        final sName = items.first.supplierName;

        // Use the sessionStockId as the document ID for stockIn
        final stockInRef = _db.collection('stockIn').doc(sessionStockId);

        final totalQuantityUnits = items.fold(0, (sum, i) => sum + i.totalUnits);

        // Header data
        batchWrite.set(stockInRef, {
          'stockId': sessionStockId, // Use session ID here
          'supplierId': sId,
          'supplierName': sName,
          'receivedDate': now,
          'createdBy': user.uid,
          'notes': _notesController.text.trim(),
          'totalItems': items.length,
          'totalQuantity': totalQuantityUnits,
        }, SetOptions(merge: true)); // Use merge if multiple suppliers in one session

        for (var item in items) {
          final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
          final randomSuffix = DateTime.now().microsecondsSinceEpoch.toString().substring(10);
          final batchNumber = "BATCH-$dateStr-$randomSuffix";

          final stockInItemRef = stockInRef.collection('items').doc();
          batchWrite.set(stockInItemRef, {
            'itemId': stockInItemRef.id,
            'productId': item.productId,
            'productName': item.productName,
            'batchNumber': batchNumber,
            'expiryDate': Timestamp.fromDate(item.expiryDate),
            'quantity': item.totalUnits,
          });

          // Connect Batch collection using the same stockId
          final batchRef = _db.collection('batches').doc();
          batchWrite.set(batchRef, {
            'batchId': batchRef.id,
            'stockId': sessionStockId, // Shared ID
            'batchNumber': batchNumber,
            'productId': item.productId,
            'productName': item.productName,
            'initialQuantity': item.totalUnits,
            'currentQuantity': item.totalUnits,
            'expiryDate': Timestamp.fromDate(item.expiryDate),
            'receivedDate': now,
            'status': 'active',
            'supplierId': sId,
            'supplierName': sName,
            'createdAt': now,
          });

          batchWrite.update(_db.collection('products').doc(item.productId), {
            'currentStock': FieldValue.increment(item.totalUnits),
            'updatedAt': now,
          });

          final movementRef = _db.collection('stockMovements').doc();
          batchWrite.set(movementRef, {
            'movementId': movementRef.id,
            'stockId': sessionStockId, // Unified ID
            'productId': item.productId,
            'productName': item.productName,
            'quantity': item.totalUnits,
            'type': 'Stock In',
            'reason': 'Inventory Received - Session $sessionStockId',
            'timestamp': now,
            'user': widget.username,
          });
        }
      }

      await batchWrite.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Stock Confirmed! ID: $sessionStockId'),
            backgroundColor: Colors.green
        ));
        setState(() { batchItems.clear(); _notesController.clear(); selectedSupplierName = null; });
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); _showError('Error: $e'); }
    }
  }

  Future<void> _scanBarcode() async {
    final scannedBarcode = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
    if (scannedBarcode == null || scannedBarcode.isEmpty) return;

    dynamic searchKey;
    int? intBarcode = int.tryParse(scannedBarcode);
    searchKey = intBarcode ?? scannedBarcode;

    final query = await _db.collection('products').where('barcodeNo', isEqualTo: searchKey).limit(1).get();

    if (query.docs.isEmpty) { _showError('Product not found!'); return; }

    final doc = query.docs.first;
    final data = doc.data();

    if (data['supplier'] != selectedSupplierName) {
      _showError('Product belongs to ${data['supplier']}');
      return;
    }

    _addBatchItem(
      doc.id,
      data['productName'],
      (data['barcodeNo'] ?? '-').toString(),
      data['imageUrl'],
      data['unitsPerCarton'] ?? 1,
    );
  }
}

class StockItem {
  String productId, productName, barcodeNo, supplierName, supplierId;
  String? imageUrl;
  int quantity;
  int unitsPerCarton;
  DateTime expiryDate;

  StockItem({
    required this.productId,
    required this.productName,
    required this.barcodeNo,
    required this.supplierName,
    required this.supplierId,
    this.imageUrl,
    required this.quantity,
    required this.unitsPerCarton,
    required this.expiryDate});

  int get totalUnits => quantity * unitsPerCarton;
}