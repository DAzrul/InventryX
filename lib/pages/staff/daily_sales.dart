import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; //

class ProductLocalState {
  final String id;
  final String name;
  final String sku;
  final double price;
  final int currentStock;
  final String category;
  final String? imageUrl;
  int soldQty;

  ProductLocalState({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.currentStock,
    required this.category,
    this.imageUrl,
    this.soldQty = 0,
  });
}

class DailySalesPage extends StatefulWidget {
  const DailySalesPage({super.key});

  @override
  State<DailySalesPage> createState() => _DailySalesPageState();
}

class _DailySalesPageState extends State<DailySalesPage> {
  bool _isLoading = true;
  List<ProductLocalState> _allProducts = [];
  List<String> _uniqueCategories = ["All"];
  String _selectedCategory = "All";
  String _searchQuery = "";
  final TextEditingController _remarksController = TextEditingController();
  final Color primaryColor = const Color(0xFF233E99);

  double get _totalSalesAmount => _allProducts.fold(0, (sum, p) => sum + (p.price * p.soldQty));
  int get _totalItemsSold => _allProducts.fold(0, (sum, p) => sum + p.soldQty);

  @override
  void initState() {
    super.initState();
    _fetchAndRandomizeData();
  }

  // ==========================================================
  // FUNGSI 1: ACCUMULATIVE RANDOMIZE (NOMBOR SENTIASA NAIK)
  // ==========================================================
  void _randomizeAllSales() {
    final Random random = Random();
    setState(() {
      for (var product in _allProducts) {
        // Hanya tambah kalau jualan belum cecah limit stok
        if (product.currentStock > product.soldQty) {

          // 50% chance untuk ada tambahan jualan dlm klik ni
          if (random.nextDouble() < 0.5) {
            int remaining = product.currentStock - product.soldQty;

            // Kita hadkan penambahan max 5 unit setiap kali klik
            int maxToAdd = remaining > 5 ? 5 : remaining;
            int extraQty = random.nextInt(maxToAdd) + 1;

            // Guna += supaya nilai sentiasa bertambah, bukan reset
            product.soldQty += extraQty;
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sales ! Sales Update ."),
          backgroundColor: Colors.indigo,
          duration: Duration(milliseconds: 800),
        )
    );
  }

  // ==========================================================
  // FUNGSI 2: BARCODE SCANNER (MACAM CASHIER)
  // ==========================================================
  void _openBarcodeScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null) {
                    _processScannedCode(code);
                    Navigator.pop(context);
                    break;
                  }
                }
              },
            ),
            // Laser Effect
            Positioned(
              top: 20, left: 0, right: 0,
              child: Center(child: Container(width: 200, height: 2, color: Colors.redAccent)),
            ),
            Center(
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processScannedCode(String code) {
    int index = _allProducts.indexWhere((p) => p.sku == code);
    if (index != -1) {
      setState(() {
        if (_allProducts[index].soldQty < _allProducts[index].currentStock) {
          _allProducts[index].soldQty++; // Scan pun bersifat accumulative
          _selectedCategory = "All";
          _searchQuery = "";
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Added: ${_allProducts[index].name}"), backgroundColor: primaryColor)
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product not found!"), backgroundColor: Colors.red)
      );
    }
  }

  // ==========================================================
  // FUNGSI 3: FETCH DATA DARI FIREBASE
  // ==========================================================
  Future<void> _fetchAndRandomizeData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      List<ProductLocalState> tempList = [];
      Set<String> categoriesSet = {"All"};

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String cat = data['category'] ?? 'Others';
        categoriesSet.add(cat);
        double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;
        int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

        tempList.add(ProductLocalState(
          id: doc.id,
          name: data['productName'] ?? 'Unknown',
          sku: data['barcodeNo']?.toString() ?? data['sku'] ?? '-',
          currentStock: stock,
          category: cat,
          price: price,
          imageUrl: data['imageUrl'] ?? data['image'],
          soldQty: 0,
        ));
      }

      if (mounted) {
        setState(() {
          _allProducts = tempList;
          _uniqueCategories = categoriesSet.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================
  // FUNGSI 4: SAVE KE FIREBASE (PENDING DEDUCTION)
  // ==========================================================
  Future<void> _saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final itemsToSave = _allProducts.where((p) => p.soldQty > 0).toList();
    if (itemsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No items to save!")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final batchWrite = FirebaseFirestore.instance.batch();
      final salesRef = FirebaseFirestore.instance.collection('sales');
      final now = Timestamp.now();

      for (var item in itemsToSave) {
        var newDoc = salesRef.doc();
        batchWrite.set(newDoc, {
          'salesID': newDoc.id,
          'productID': item.id,
          'userID': user.uid,
          'quantitySold': item.soldQty,
          'totalAmount': item.price * item.soldQty,
          'saleDate': now,
          'snapshotName': item.name,
          'status': 'pending_deduction',
          'remarks': _remarksController.text.trim(),
        });
      }

      await batchWrite.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Simulation Saved!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _allProducts.where((p) {
      final matchesCat = _selectedCategory == "All" || p.category == _selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || p.sku.contains(_searchQuery);
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text("Daily Sales", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black)),
        centerTitle: true,
        actions: [
          // Butang Magic Randomize
          IconButton(
            onPressed: _randomizeAllSales,
            icon: Icon(Icons.auto_fix_high_rounded, color: Colors.orange.shade800),
          ),
          IconButton(
            onPressed: _openBarcodeScanner,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.qr_code_scanner_rounded, color: primaryColor, size: 20),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildSearchSection(),
          _buildCategorySection(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) => _ProductListItem(
                product: filteredItems[index],
                onQtyChanged: (val) => setState(() {
                  int idx = _allProducts.indexWhere((p) => p.id == filteredItems[index].id);
                  _allProducts[idx].soldQty = val;
                }),
              ),
            ),
          ),
          _buildRemarksSection(),
          const SizedBox(height: 120),
        ],
      ),
      bottomSheet: _buildBottomSummary(),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(hintText: "Search Product...", prefixIcon: Icon(Icons.search, color: primaryColor), border: InputBorder.none),
      ),
    );
  }

  Widget _buildCategorySection() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: _uniqueCategories.map((cat) {
          final isSel = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: isSel ? primaryColor : Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Center(child: Text(cat, style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRemarksSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: TextField(
          controller: _remarksController,
          maxLines: 2,
          decoration: const InputDecoration(hintText: "Add today's simulation notes...", border: InputBorder.none, hintStyle: TextStyle(fontSize: 13))
      ),
    );
  }

  Widget _buildBottomSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 15, 24, 30),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text("Estimated Total Amount", style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
            Text("RM ${_totalSalesAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
          ]),
          ElevatedButton(
            onPressed: _saveToFirebase,
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0
            ),
            child: const Text("Save & Record", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ProductListItem extends StatelessWidget {
  final ProductLocalState product;
  final Function(int) onQtyChanged;
  const _ProductListItem({required this.product, required this.onQtyChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]
      ),
      child: Row(
        children: [
          // Gambar Produk
          Container(
            width: 55, height: 55,
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                  ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.inventory_2_rounded, color: Colors.blueGrey),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text("Bal: ${product.currentStock} | RM ${product.price}", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ])),
          Row(children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24), onPressed: () => onQtyChanged(max(0, product.soldQty - 1))),
            Container(width: 30, alignment: Alignment.center, child: Text("${product.soldQty}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 24), onPressed: () => onQtyChanged(min(product.currentStock, product.soldQty + 1))),
          ]),
        ],
      ),
    );
  }
}