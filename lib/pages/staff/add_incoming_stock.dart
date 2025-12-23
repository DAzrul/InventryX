import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'stock_display.dart';
import 'stock_out.dart';

class AddIncomingStockPage extends StatefulWidget {
  @override
  State<AddIncomingStockPage> createState() => _AddIncomingStockPageState();
}

class _AddIncomingStockPageState extends State<AddIncomingStockPage> {
  final Color mainBlue = const Color(0xFF00147C);
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? selectedSupplier;
  List<Stock> batchItems = [];

  int _selectedTab = 0;

  int get totalQuantity =>
      batchItems.fold(0, (sum, item) => sum + item.quantity);

  bool get hasQuantity =>
      batchItems.any((item) => item.quantity > 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: mainBlue,
        title: const Text('Add Incoming Stock'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _segmentedControl(),
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
          _bottomSection(),
        ],
      ),
    );
  }

  // ======================== SEGMENTED CONTROL ========================
  Widget _segmentedControl() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Stock In')),
          ButtonSegment(value: 1, label: Text('Stock Display')),
          ButtonSegment(value: 2, label: Text('Stock Out')),
        ],
        selected: {_selectedTab},
        onSelectionChanged: (value) {
          final selected = value.first;
          if (selected == _selectedTab) return; // avoid reloading same page

          Widget page;
          switch (selected) {
            case 0:
              page = AddIncomingStockPage();
              break;
            case 1:
              page = StockDisplayPage();
              break;
            case 2:
              page = StockOutPage();
              break;
            default:
              return;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          selectedBackgroundColor: const Color(0xFF00147C),
          selectedForegroundColor: Colors.white,
        ),
      ),
    );
  }



  // ======================== SUPPLIER DROPDOWN ========================
  Widget _supplierDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Supplier",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('supplier').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final supplier = snapshot.data!.docs;

            return DropdownButtonFormField<String>(
              value: selectedSupplier,
              hint: const Text('Select supplier'),
              items: supplier.map<DropdownMenuItem<String>>((doc) {
                final supplierName = doc['supplierName'] as String;

                return DropdownMenuItem<String>(
                  value: supplierName,
                  child: Text(supplierName),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() {
                  selectedSupplier = value;
                  batchItems.clear();
                });
              },
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ======================== FIND PRODUCT ========================
  Widget _findProductField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Find Products",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                onTap: selectedSupplier == null ? null : _showProductDialog,
                decoration: const InputDecoration(
                  hintText: 'Search by name or SKU',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.qr_code_scanner),
            ),
          ],
        ),
      ],
    );
  }

  // ======================== PRODUCT SELECTION ========================
  void _showProductDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('products')
              .where('supplier', isEqualTo: selectedSupplier)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final products = snapshot.data!.docs;

            if (products.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No products found')),
              );
            }

            return ListView(
              children: products.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final productId = doc.id;
                final productName = data['productName'] as String;
                final barcodeNo = data['barcodeNo'].toString();
                final imageUrl =
                data.containsKey('imageUrl') ? data['imageUrl'] as String? : null;

                return ListTile(
                  leading: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.shopping_bag),
                  title: Text(productName),
                  subtitle: Text('Barcode: $barcodeNo'),
                  onTap: () {
                    _addBatchItem(productId, productName, barcodeNo, imageUrl);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  void _addBatchItem(
      String productId,
      String productName,
      String barcodeNo,
      String? imageUrl,
      ) {
    final exists = batchItems.any((item) => item.productId == productId);

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product already added'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      batchItems.add(
        Stock(
          productId: productId,
          productName: productName,
          barcodeNo: barcodeNo,
          imageUrl: imageUrl,
          quantity: 0,
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          lastRestockedDate: DateTime.now(),
          supplierName: selectedSupplier!,
        ),
      );
    });
  }

  // ======================== BATCH LIST ========================
  Widget _batchList() {
    if (batchItems.isEmpty) {
      return const Center(child: Text('No products added'));
    }

    return Column(
      children: batchItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        final qtyController =
        TextEditingController(text: item.quantity.toString());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.shopping_bag),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName,
                              style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Barcode: ${item.barcodeNo}',
                              style: const TextStyle(fontSize: 12)),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    _qtyButton(
                      icon: Icons.remove,
                      onTap: () {
                        setState(() {
                          if (item.quantity > 0) item.quantity--;
                        });
                      },
                    ),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (value) {
                          final qty = int.tryParse(value);
                          if (qty != null && qty >= 0) {
                            setState(() => item.quantity = qty);
                          }
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                          EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                    _qtyButton(
                      icon: Icons.add,
                      onTap: () =>
                          setState(() => item.quantity++),
                    ),
                    const Spacer(),
                    _expiryPicker(item),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _expiryPicker(Stock item) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: item.expiryDate,
          firstDate: DateTime.now(),
          lastDate: DateTime(2035),
        );
        if (date != null) {
          setState(() => item.expiryDate = date);
        }
      },
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16),
          const SizedBox(width: 6),
          Text(
            '${item.expiryDate.day}/${item.expiryDate.month}/${item.expiryDate.year}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ======================== SAVE ========================
  Widget _bottomSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Items: ${batchItems.length}'),
              Text('Total Quantity: $totalQuantity'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: mainBlue),
              onPressed: hasQuantity ? _saveStock : null,
              child: const Text('Update and Save'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveStock() async {
    final now = DateTime.now();

    print('SAVE BUTTON PRESSED');

    for (var item in batchItems) {
      if (item.quantity > 0) {
        await _db.collection('stock').add({
          'productId': item.productId,
          'quantity': item.quantity,
          'expiryDate': Timestamp.fromDate(item.expiryDate),
          'lastRestockedDate': Timestamp.fromDate(now),
        });

        print('✅ SAVED ${item.productId}');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stock saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// ======================== MODEL ========================
class Stock {
  String productId;
  String productName;
  String barcodeNo;
  String? imageUrl;
  int quantity;
  DateTime expiryDate;
  DateTime lastRestockedDate;
  String supplierName;

  Stock({
    required this.productId,
    required this.productName,
    required this.barcodeNo,
    this.imageUrl,
    required this.quantity,
    required this.expiryDate,
    required this.lastRestockedDate,
    required this.supplierName,
  });
}
