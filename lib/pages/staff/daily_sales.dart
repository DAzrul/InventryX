import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProductLocalState {
  final String id;
  final String name;
  final String sku;
  final double price;
  final int currentStock;
  final String category;
  int soldQty;

  ProductLocalState({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.currentStock,
    required this.category,
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
  final TextEditingController _remarksController = TextEditingController();

  double get _totalSalesAmount => _allProducts.fold(0, (sum, p) => sum + (p.price * p.soldQty));
  int get _totalItemsSold => _allProducts.fold(0, (sum, p) => sum + p.soldQty);

  @override
  void initState() {
    super.initState();
    _fetchAndRandomizeData();
  }

  // --- 1. TARIK DATA & RANDOMIZE (STOK > 0 SAHAJA) ---
  Future<void> _fetchAndRandomizeData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      final Random random = Random();
      List<ProductLocalState> tempList = [];
      Set<String> categoriesSet = {"All"};

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String cat = data['category'] ?? 'Others';
        categoriesSet.add(cat);

        double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;

        // Baca field currentStock ikut schema kau
        int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

        int randomQty = 0;

        // Logik: Hanya generate sold quantity kalau stok ada (lebih dari 0)
        if (stock > 0) {
          bool isSoldToday = random.nextDouble() < 0.7; // 70% chance terjual
          if (isSoldToday) {
            // Random jualan antara 1 hingga stok sedia ada (kita hadkan max 5 unit)
            int maxPossibleSale = stock > 5 ? 5 : stock;
            randomQty = random.nextInt(maxPossibleSale) + 1;
          }
        }

        tempList.add(ProductLocalState(
          id: doc.id,
          name: data['productName'] ?? 'Unknown',
          sku: data['barcodeNo']?.toString() ?? data['sku'] ?? '-',
          currentStock: stock,
          category: cat,
          price: price,
          soldQty: randomQty,
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
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. SAVE SALES SEBAGAI PENDING ---
  Future<void> _saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final itemsToSave = _allProducts.where((p) => p.soldQty > 0).toList();
    if (itemsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No items with sales to save!"), backgroundColor: Colors.orange)
      );
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
          'status': 'pending_deduction', // Penting: Untuk Stock Out apply nanti
          'remarks': _remarksController.text.trim(),
        });
      }

      await batchWrite.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Daily sales record saved as PENDING."), backgroundColor: Colors.green)
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _selectedCategory == "All"
        ? _allProducts
        : _allProducts.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context)
        ),
        title: const Text("Daily Sales Input", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _fetchAndRandomizeData,
            icon: const Icon(Icons.refresh, color: Colors.blue),
            tooltip: "Regenerate Sales Data",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchSection(),
            _buildCategorySection(),
            if (filteredItems.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No products found.")))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  return _ProductListItem(
                    product: filteredItems[index],
                    onQtyChanged: (val) => setState(() {
                      int idx = _allProducts.indexWhere((p) => p.id == filteredItems[index].id);
                      _allProducts[idx].soldQty = val;
                    }),
                  );
                },
              ),
            _buildRemarksSection(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: _buildBottomSummary(),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Find Products", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search by name or SKU",
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.qr_code_scanner, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Row(
        children: _uniqueCategories.map((cat) => GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: _selectedCategory == cat ? const Color(0xFFDEE2E6) : const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(cat, style: TextStyle(color: Colors.black87, fontWeight: _selectedCategory == cat ? FontWeight.bold : FontWeight.normal)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildRemarksSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Remarks (Optional)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _remarksController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Add any notes about today's sales...",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Items Sold:"), Text("$_totalItemsSold")]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Sales Amount:", style: TextStyle(fontSize: 16)), Text("RM${_totalSalesAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(backgroundColor: const Color(0xFFF1F3F5), side: BorderSide.none, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Cancel", style: TextStyle(color: Colors.black54)))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: _saveToFirebase, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF20338F), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Save", style: TextStyle(color: Colors.white)))),
            ],
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: Colors.indigo, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text("Stock: ${product.currentStock} | RM${product.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 24, color: Colors.redAccent),
                  onPressed: () => onQtyChanged(max(0, product.soldQty - 1))
              ),
              SizedBox(
                  width: 30,
                  child: Center(child: Text("${product.soldQty}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))
              ),
              IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 24, color: Colors.green),
                  onPressed: () => onQtyChanged(min(product.currentStock, product.soldQty + 1))
              ),
            ],
          ),
        ],
      ),
    );
  }
}