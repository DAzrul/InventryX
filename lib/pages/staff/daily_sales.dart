import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- MODEL PRODUK LOCAL ---
class ProductLocalState {
  final String id;
  final String name;
  final String sku;
  final double price;
  final int currentStock; // Stok yang valid (belum expired)
  final String category;
  final String? imageUrl;
  int soldQty; // Kuantiti yang nak dijual

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

  // Warna Tema
  final Color primaryColor = const Color(0xFF203288);

  // Getters untuk Total
  double get _totalSalesAmount => _allProducts.fold(0, (sum, p) => sum + (p.price * p.soldQty));
  int get _totalItemsSold => _allProducts.fold(0, (sum, p) => sum + p.soldQty);

  // Senarai barang dalam bakul
  List<ProductLocalState> get _cartItems => _allProducts.where((p) => p.soldQty > 0).toList();

  @override
  void initState() {
    super.initState();
    _fetchAndRandomizeData();
  }

  // ==========================================================
  // 1. FETCH DATA (LOGIC STOK VALID + FALLBACK)
  // ==========================================================
  Future<void> _fetchAndRandomizeData() async {
    setState(() => _isLoading = true);
    try {
      final DateTime now = DateTime.now();
      Map<String, int> validStockMap = {};

      // A. Cuba tarik dari Batches (Stok ikut Tarikh Luput)
      try {
        final batchSnapshot = await FirebaseFirestore.instance
            .collection('batches')
            .where('expiryDate', isGreaterThan: Timestamp.fromDate(now)) // Hanya ambil yang belum expired
            .where('currentQuantity', isGreaterThan: 0)
            .get();

        for (var doc in batchSnapshot.docs) {
          String pid = doc['productId'];
          int qty = int.tryParse(doc['currentQuantity'].toString()) ?? 0;
          validStockMap[pid] = (validStockMap[pid] ?? 0) + qty;
        }
      } catch (e) {
        debugPrint("Batch Index Error (Abaikan jika belum setup index): $e");
      }

      // B. Tarik Produk Utama
      final productSnapshot = await FirebaseFirestore.instance.collection('products').get();
      List<ProductLocalState> tempList = [];
      Set<String> categoriesSet = {"All"};

      for (var doc in productSnapshot.docs) {
        var data = doc.data();
        String pid = doc.id;
        String cat = data['category'] ?? 'Others';
        categoriesSet.add(cat);

        double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;

        // Logic Stok: Guna batch valid dulu, kalau 0/tak ada, baru guna stok general (fallback)
        int batchStock = validStockMap[pid] ?? 0;
        int productStock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

        // Kalau Batch system jalan, guna batchStock. Kalau tak, guna productStock.
        int finalStock = batchStock > 0 ? batchStock : productStock;

        tempList.add(ProductLocalState(
          id: pid,
          name: data['productName'] ?? 'Unknown',
          sku: data['barcodeNo']?.toString() ?? data['sku'] ?? '-',
          currentStock: finalStock,
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
      debugPrint("Error Fetching Data: $e");
    }
  }

  // ==========================================================
  // 2. AUTO GENERATE SALES (UTK DEMO/TESTING)
  // ==========================================================
  void _randomizeAllSales() {
    final Random random = Random();
    int itemsUpdated = 0;

    setState(() {
      for (var product in _allProducts) {
        // Cek stok cukup tak sebelum auto-add
        if (product.currentStock > product.soldQty) {
          if (random.nextDouble() < 0.5) { // 50% chance
            int remaining = product.currentStock - product.soldQty;
            int maxToAdd = remaining > 5 ? 5 : remaining; // Max tambah 5 sekali jalan
            int extraQty = random.nextInt(maxToAdd) + 1;
            product.soldQty += extraQty;
            itemsUpdated++;
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(itemsUpdated > 0 ? "Sales Generated Automatically!" : "No valid stock available."),
          backgroundColor: itemsUpdated > 0 ? primaryColor : Colors.orange,
          duration: const Duration(milliseconds: 1000),
        )
    );
  }

  // ==========================================================
  // 3. BARCODE SCANNER
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
                  if (barcode.rawValue != null) {
                    _processScannedCode(barcode.rawValue!);
                    Navigator.pop(context);
                    break;
                  }
                }
              },
            ),
            // Kotak Merah (Target)
            Center(
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(border: Border.all(color: Colors.redAccent, width: 2)),
              ),
            ),
            const Positioned(
              bottom: 30, left: 0, right: 0,
              child: Text("Align barcode within frame", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }

  void _processScannedCode(String code) {
    int index = _allProducts.indexWhere((p) => p.sku == code);
    if (index != -1) {
      if (_allProducts[index].soldQty < _allProducts[index].currentStock) {
        setState(() {
          _allProducts[index].soldQty++;
          _selectedCategory = "All"; // Reset filter
          _searchQuery = ""; // Reset search
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Added: ${_allProducts[index].name}"), backgroundColor: primaryColor, duration: const Duration(milliseconds: 800))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Stock Limit Reached!"), backgroundColor: Colors.orange)
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product not found!"), backgroundColor: Colors.red)
      );
    }
  }

  // ==========================================================
  // 4. SAVE TO FIREBASE
  // ==========================================================
  Future<void> _saveToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No items to save!"), backgroundColor: Colors.orange));
      return;
    }

    // Tunjuk Loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final batchWrite = FirebaseFirestore.instance.batch();
      final salesRef = FirebaseFirestore.instance.collection('sales');
      final now = Timestamp.now();

      for (var item in _cartItems) {
        var newDoc = salesRef.doc();
        batchWrite.set(newDoc, {
          'salesID': newDoc.id,
          'productID': item.id,
          'userID': user.uid,
          'quantitySold': item.soldQty,
          'totalAmount': item.price * item.soldQty,
          'saleDate': now,
          'snapshotName': item.name,
          'status': 'pending_deduction', // Status penting untuk proses seterusnya
          'remarks': _remarksController.text.trim(),
        });
      }

      await batchWrite.commit();

      if (mounted) {
        Navigator.pop(context); // Tutup Loading Dialog
        Navigator.pop(context); // Tutup Page Daily Sales (Balik ke Menu)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sales Recorded Successfully!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Tutup Loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // ==========================================================
  // UI UTAMA
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    // Filter List
    final filteredItems = _allProducts.where((p) {
      final matchesCat = _selectedCategory == "All" || p.category == _selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || p.sku.contains(_searchQuery);
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text("Daily Sales Input", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _randomizeAllSales,
            tooltip: "Auto Generate Sales",
            icon: Icon(Icons.auto_fix_high_rounded, color: Colors.orange.shade800),
          ),
          IconButton(
            onPressed: _openBarcodeScanner,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.qr_code_scanner_rounded, color: primaryColor, size: 20),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // Guna Stack supaya Bottom Sheet boleh duduk atas Content
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // LAYER 1: Main Content
          Column(
            children: [
              _buildSearchSection(),
              _buildCategorySection(),
              Expanded(
                child: ListView.builder(
                  // Padding bawah besar sikit supaya item last tak tertutup dengan bottom sheet
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 180),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) => _ProductListItem(
                    product: filteredItems[index],
                    onQtyChanged: (val) => setState(() {
                      // Cari item sebenar dalam _allProducts berdasarkan ID
                      int idx = _allProducts.indexWhere((p) => p.id == filteredItems[index].id);
                      if (idx != -1) _allProducts[idx].soldQty = val;
                    }),
                  ),
                ),
              ),
            ],
          ),

          // LAYER 2: Draggable Bottom Sheet (POS Style)
          _buildDraggableBottomSummary(),
        ],
      ),
    );
  }

  // --- WIDGET CARIAN ---
  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.all(20), padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(hintText: "Search Product...", prefixIcon: Icon(Icons.search, color: primaryColor), border: InputBorder.none),
      ),
    );
  }

  // --- WIDGET KATEGORI ---
  Widget _buildCategorySection() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
        children: _uniqueCategories.map((cat) {
          final isSel = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                  color: isSel ? primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isSel ? Colors.transparent : Colors.grey.shade200)
              ),
              child: Center(child: Text(cat, style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- [UTAMA] DRAGGABLE BOTTOM SHEET ---
  Widget _buildDraggableBottomSummary() {
    return DraggableScrollableSheet(
      initialChildSize: 0.18, // Saiz mula (Nampak Total & Button shj)
      minChildSize: 0.18,     // Paling kecil
      maxChildSize: 0.75,     // Paling besar (bila tarik)
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -5))]
          ),
          child: Column(
            children: [
              // 1. Handle Bar (Pengayuh)
              const SizedBox(height: 12),
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),

              // 2. Header (FIXED AT TOP): Total & Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 15, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Kolum Total
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Total Sales (${_totalItemsSold} items)", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text("RM ${_totalSalesAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
                      ],
                    ),
                    // Butang Confirm
                    ElevatedButton(
                      onPressed: _saveToFirebase,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                          shadowColor: primaryColor.withOpacity(0.4)
                      ),
                      child: const Text("Confirm & Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 3. List Item (SCROLLABLE)
              // Bahagian ini akan scroll bila sheet ditarik ke atas
              Expanded(
                child: _cartItems.isEmpty
                    ? Center(child: Text("Swipe up to see list details", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)))
                    : ListView.builder(
                  controller: scrollController, // Wajib pass controller ni
                  padding: const EdgeInsets.all(24),
                  itemCount: _cartItems.length + 1, // +1 untuk Remarks
                  itemBuilder: (context, index) {
                    // Item Terakhir: Remarks Box
                    if (index == _cartItems.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 40),
                        child: TextField(
                            controller: _remarksController,
                            maxLines: 2,
                            decoration: InputDecoration(
                                hintText: "Add remarks (optional)...",
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                            )
                        ),
                      );
                    }

                    // List Item Produk
                    final item = _cartItems[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        children: [
                          // Kuantiti Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text("${item.soldQty}x", style: TextStyle(fontWeight: FontWeight.w900, color: primaryColor)),
                          ),
                          const SizedBox(width: 15),
                          // Nama
                          Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                          // Harga
                          Text("RM ${(item.price * item.soldQty).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- ITEM PRODUK LIST (SERAGAM DESIGN) ---
class _ProductListItem extends StatelessWidget {
  final ProductLocalState product;
  final Function(int) onQtyChanged;
  const _ProductListItem({required this.product, required this.onQtyChanged});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF203288);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
      ),
      child: Row(
        children: [
          // Gambar
          _buildProductImage(product.imageUrl, size: 55, primaryColor: primaryBlue),

          const SizedBox(width: 15),

          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Text("Stock: ${product.currentStock}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text("RM ${product.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w900)),
            ]),
          ])),

          // Butang Tambah/Tolak
          Row(children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24), onPressed: () => onQtyChanged(max(0, product.soldQty - 1))),
            Container(width: 30, alignment: Alignment.center, child: Text("${product.soldQty}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: product.soldQty > 0 ? primaryBlue : Colors.black))),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 24), onPressed: () => onQtyChanged(min(product.currentStock, product.soldQty + 1))),
          ]),
        ],
      ),
    );
  }

  Widget _buildProductImage(String? url, {double size = 55, required Color primaryColor}) {
    if (url == null || url.isEmpty) {
      return Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryColor.withOpacity(0.1), width: 1.5)), child: Center(child: Icon(Icons.inventory_2_rounded, color: primaryColor.withOpacity(0.3), size: size * 0.5)));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover, placeholder: (_, __) => Container(width: size, height: size, color: Colors.grey[100]), errorWidget: (_, __, ___) => Container(width: size, height: size, color: Colors.grey[100], child: Icon(Icons.error, color: Colors.grey))));
  }
}