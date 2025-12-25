import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'stock_out.dart';
import '../Features_app/barcode_scanner_page.dart';

class AddIncomingStockPage extends StatefulWidget {
  const AddIncomingStockPage({super.key});

  @override
  State<AddIncomingStockPage> createState() => _AddIncomingStockPageState();
}

class _AddIncomingStockPageState extends State<AddIncomingStockPage> {
  final Color mainBlue = const Color(0xFF00147C);
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _searchQuery = '';

  String? selectedSupplierName;
  String? selectedSupplierId;

  List<StockItem> batchItems = [];
  int _selectedTab = 0;

  int get totalQuantity =>
      batchItems.fold(0, (sum, item) => sum + item.quantity);

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
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: mainBlue,
        title: const Text('Add Incoming Stock'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _supplierDropdown(),
                  const SizedBox(height: 24),
                  _findProductField(),
                  const SizedBox(height: 24),
                  _batchList(),
                ],
              ),
            ),
          ),
          // FOOTER (Notes + Totals + Button)
          _bottomSection(),
        ],
      ),
    );
  }

  Widget _supplierDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Supplier",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('supplier').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();

            final suppliers = snapshot.data!.docs;

            return DropdownButtonFormField<String>(
              value: selectedSupplierName,
              hint: const Text('Select supplier'),
              items: suppliers.map<DropdownMenuItem<String>>((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['supplierName'] as String;
                return DropdownMenuItem<String>(
                  value: name,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedSupplierName = newValue;
                  batchItems.clear();

                  if (newValue != null) {
                    try {
                      final selectedDoc = suppliers.firstWhere(
                              (doc) =>
                          (doc.data() as Map<String,
                              dynamic>)['supplierName'] == newValue
                      );
                      selectedSupplierId = selectedDoc.id;
                    } catch (e) {
                      selectedSupplierId = 'Unknown';
                    }
                  } else {
                    selectedSupplierId = null;
                  }
                });
              },
              decoration: const InputDecoration(
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _findProductField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Find Products",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                onTap: selectedSupplierName == null ? null : _showProductDialog,
                decoration: InputDecoration(
                  hintText: 'Search by name or barcode',
                  filled: true,
                  fillColor: selectedSupplierName == null
                      ? Colors.grey.shade100
                      : Colors.white,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: selectedSupplierName == null ? null : _scanBarcode,
              child: Container(
                height: 56, width: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.qr_code_scanner),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _notesField() {
    return TextField(
      controller: _notesController,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Notes (Optional)',
        hintText: 'Regular stock in, additional, etc.',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  // ======================== LOGIC ========================

  void _showProductDialog() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20, left: 16, right: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Select Product", style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setModalState(() {
                          _searchQuery = value.toLowerCase().trim();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Type to filter...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('products')
                            .where('supplier', isEqualTo: selectedSupplierName)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(
                              child: CircularProgressIndicator());

                          final allProducts = snapshot.data!.docs;
                          final filteredProducts = allProducts.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['productName'] ?? '').toString().toLowerCase();
                            final barcode = (data['barcodeNo'] ?? data['sku'] ?? '').toString().toLowerCase();
                            if (_searchQuery.isEmpty) return true;
                            return name.contains(_searchQuery) ||
                                barcode.contains(_searchQuery);
                          }).toList();

                          if (filteredProducts.isEmpty) return const Center(
                              child: Text('No products found.'));

                          return ListView.builder(
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final doc = filteredProducts[index];
                              final data = doc.data() as Map<String, dynamic>;
                              return ListTile(
                                leading: data['imageUrl'] != null &&
                                    data['imageUrl'].isNotEmpty
                                    ? Image.network(data['imageUrl'], width: 50,
                                    height: 50,
                                    fit: BoxFit.cover)
                                    : Container(width: 50,
                                    height: 50,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.inventory_2)),
                                title: Text(data['productName'] ?? 'Unknown'),
                                subtitle: Text(
                                    'Barcode: ${data['barcodeNo'] ?? '-'}'),
                                trailing: const Icon(Icons.add_circle_outline,
                                    color: Colors.blue),
                                onTap: () {
                                  _addBatchItem(
                                      doc.id, data['productName'],
                                      (data['barcodeNo'] ?? data['sku'] ?? '-')
                                          .toString(),
                                      data['imageUrl']
                                  );
                                  _searchController.clear();
                                  _searchQuery = '';
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _scanBarcode() async {
    final scannedBarcode = await Navigator.push<String>(
      context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );


    if (scannedBarcode == null || scannedBarcode.isEmpty) return;

    final query = await _db.collection('products')
        .where('barcodeNo', isEqualTo: scannedBarcode)
        .limit(1)
        .get();


    if (query.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product with barcode $scannedBarcode not found!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final doc = query.docs.first;
    final data = doc.data();

    _addBatchItem(
        doc.id,
        data['productName'],
        (data['barcodeNo'] ?? data['sku'] ?? '-').toString(),
        data['imageUrl']
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red)
    );
  }
  void _addBatchItem(String productId, String? productName, String barcodeNo, String? imageUrl) {
    // ... kod sedia ada anda ...
    setState(() {
      batchItems.add(StockItem(
        productId: productId,
        productName: productName ?? 'Unknown',
        barcodeNo: barcodeNo,
        imageUrl: imageUrl,
        quantity: 0,
        // TUKAR DI SINI: Guna DateTime.now() bukannya tambah 180 hari
        expiryDate: DateTime.now(),
      ));
    });
  }

  Widget _batchList() {
    if (batchItems.isEmpty) return const Center(child: Text('No products added'));
    return Column(
      children: batchItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final qtyController = TextEditingController(text: item.quantity.toString());
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8)),
                      child: item.imageUrl != null
                          ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.shopping_bag),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName, style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                          Text('Code: ${item.barcodeNo}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          setState(() => batchItems.removeAt(index)),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    _qtyButton(icon: Icons.remove, onTap: () =>
                        setState(() {
                          if (item.quantity > 0) item.quantity--;
                        })),
                    SizedBox(width: 60, child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (val) {
                        final q = int.tryParse(val);
                        if (q != null && q >= 0) item.quantity = q;
                      },
                      decoration: const InputDecoration(
                          border: InputBorder.none),
                    )),
                    _qtyButton(icon: Icons.add, onTap: () =>
                        setState(() => item.quantity++)),
                    const Spacer(),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: item.expiryDate,
                          // TUKAR DI SINI: Pastikan firstDate adalah hari ini
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );
                        if (date != null) setState(() => item.expiryDate = date);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(DateFormat('dd/MM/yyyy').format(item.expiryDate),
                                style: TextStyle(color: Colors.orange.shade900)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300)),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _bottomSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
          ]
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _notesField(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items: ${batchItems.length}',
                    style: TextStyle(color: Colors.grey[700])),
                Text('Total Qty: $totalQuantity', style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: mainBlue),
                onPressed: hasQuantity ? _saveStockToFirebase : null,
                child: const Text('CONFIRM STOCK IN', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveStockToFirebase() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first!')));
      return;
    }
    if (selectedSupplierName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a supplier!')));
      return;
    }

    showDialog(context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final batchWrite = _db.batch();
      final now = Timestamp.now();
      final stockInRef = _db.collection('stockIn').doc();
      final stockInId = stockInRef.id;

      // 1. Save Stock In Header
      batchWrite.set(stockInRef, {
        'stockInId': stockInId,
        'supplierId': selectedSupplierId ?? 'Unknown',
        'supplierName': selectedSupplierName,
        'receivedDate': now,
        'createdBy': user.uid,
        'createdAt': now,
        'notes': _notesController.text.trim(),
        'totalItems': batchItems.length,
        'totalQuantity': totalQuantity,
      });

      for (var item in batchItems) {
        if (item.quantity <= 0) continue;

        final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
        final randomSuffix = DateTime.now().microsecondsSinceEpoch.toString().substring(8);
        final batchNumber = "BATCH-$dateStr-$randomSuffix";

        // 2. Save Item Details in Stock In
        final stockInItemRef = stockInRef.collection('items').doc();
        batchWrite.set(stockInItemRef, {
          'itemId': stockInItemRef.id,
          'productId': item.productId,
          'productName': item.productName,
          'batchNumber': batchNumber,
          'expiryDate': Timestamp.fromDate(item.expiryDate),
          'quantity': item.quantity,
          'createdAt': now,
        });

        // 3. Save to Batches collection
        final batchRef = _db.collection('batches').doc();
        final daysLeft = item.expiryDate.difference(DateTime.now()).inDays;
        batchWrite.set(batchRef, {
          'batchId': batchRef.id,
          'batchNumber': batchNumber,
          'productId': item.productId,
          'productName': item.productName,
          'initialQuantity': item.quantity,
          'currentQuantity': item.quantity,
          'expiryDate': Timestamp.fromDate(item.expiryDate),
          'daysToExpiry': daysLeft,
          'receivedDate': now,
          'status': 'active',
          'stockInId': stockInId,
          'supplierId': selectedSupplierId ?? 'Unknown',
          'createdAt': now,
        });

        // 4. UPDATE CURRENT STOCK IN PRODUCT DOCUMENT
        final productRef = _db.collection('products').doc(item.productId);
        batchWrite.update(productRef, {
          'currentStock': FieldValue.increment(item.quantity),
          'updatedAt': now,
        });
      }

      await batchWrite.commit();

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Stock saved successfully & product quantity updated!'),
            backgroundColor: Colors.green
        ));
        setState(() {
          batchItems.clear();
          _notesController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

class StockItem {
  String productId;
  String productName;
  String barcodeNo;
  String? imageUrl;
  int quantity;
  DateTime expiryDate;

  StockItem({
    required this.productId, required this.productName, required this.barcodeNo,
    this.imageUrl, required this.quantity, required this.expiryDate,
  });
}