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
  final int currentStock;
  final String category;
  final String? imageUrl;
  final bool isExpiringToday; // Barang nak expired hari ini
  final bool hasBatches;      // [BARU] Penanda adakah produk ini guna sistem batch
  int soldQty;

  ProductLocalState({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.currentStock,
    required this.category,
    this.imageUrl,
    this.isExpiringToday = false,
    this.hasBatches = false,
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

  final Color primaryColor = const Color(0xFF203288);

  // Getters
  double get _totalSalesAmount => _allProducts.fold(0, (sum, p) => sum + (p.price * p.soldQty));
  int get _totalItemsSold => _allProducts.fold(0, (sum, p) => sum + p.soldQty);
  List<ProductLocalState> get _cartItems => _allProducts.where((p) => p.soldQty > 0).toList();

  @override
  void initState() {
    super.initState();
    _fetchAndRandomizeData();
  }

  // ==========================================================
  // 1. FETCH DATA (LOGIC FIX: STRICT BATCH CHECKING)
  // ==========================================================
  Future<void> _fetchAndRandomizeData() async {
    setState(() => _isLoading = true);
    try {
      final DateTime now = DateTime.now();
      // "Expired Hari Ini" bermaksud expired antara SEKARANG hingga ESOK PAGI
      final DateTime startOfTomorrow = DateTime(now.year, now.month, now.day + 1);

      Map<String, int> validStockMap = {};   // Simpan stok yang sah
      Set<String> productsWithBatches = {};  // Simpan ID produk yang ada batch (walaupun expired)
      Set<String> expiringTodayIds = {};     // Simpan ID yang expired hari ini
      Map<String, int> pendingSalesMap = {}; // Simpan cart lama

      // A. Tarik SEMUA Batch yang ada stok (> 0) tanpa filter tarikh expiry di query
      //    Kita akan filter tarikh dalam kod supaya kita tahu batch tu wujud.
      try {
        final batchSnapshot = await FirebaseFirestore.instance
            .collection('batches')
            .where('currentQuantity', isGreaterThan: 0)
            .get();

        for (var doc in batchSnapshot.docs) {
          String pid = doc['productId'];
          int qty = int.tryParse(doc['currentQuantity'].toString()) ?? 0;
          Timestamp? expTs = doc['expiryDate'];

          // Tanda bahawa produk ini menggunakan sistem batch
          productsWithBatches.add(pid);

          if (expTs != null) {
            DateTime expiryDate = expTs.toDate();

            if (expiryDate.isAfter(now)) {
              // Batch BELUM Expired -> Masuk dalam stok valid
              validStockMap[pid] = (validStockMap[pid] ?? 0) + qty;

              // Check kalau expired hari ini (Sebelum esok pagi)
              if (expiryDate.isBefore(startOfTomorrow)) {
                expiringTodayIds.add(pid);
              }
            } else {
              // Batch SUDAH Expired -> JANGAN TAMBAH KE validStockMap
              // Tapi sebab kita dah add ke 'productsWithBatches', sistem tahu stok dia patut 0.
              debugPrint("Skipped Expired Batch for $pid: $expiryDate");
            }
          }
        }
      } catch (e) {
        debugPrint("Batch Index Error: $e");
      }

      // B. Tarik Pending Sales
      try {
        final pendingSnapshot = await FirebaseFirestore.instance.collection('pending_sales').get();
        for (var doc in pendingSnapshot.docs) {
          String pid = doc['productID'];
          int qty = int.tryParse(doc['quantitySold'].toString()) ?? 0;
          pendingSalesMap[pid] = qty;
        }
      } catch (e) {
        debugPrint("Pending Sales Error: $e");
      }

      // C. Tarik Produk Utama & Gabung Data
      final productSnapshot = await FirebaseFirestore.instance.collection('products').get();
      List<ProductLocalState> tempList = [];
      Set<String> categoriesSet = {"All"};

      for (var doc in productSnapshot.docs) {
        var data = doc.data();
        String pid = doc.id;
        String cat = data['category'] ?? 'Others';
        categoriesSet.add(cat);

        double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;
        int productMasterStock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

        // [LOGIC PENENTU STOK]
        int finalStock;

        if (productsWithBatches.contains(pid)) {
          // KES 1: Produk ada batch (Active atau Expired).
          // Kita MESTI guna stok dari batch valid.
          // Kalau semua batch expired, validStockMap[pid] akan jadi 0 (atau null).
          // Kita ABAIKAN master stock (14 tu) sebab ia tak update.
          finalStock = validStockMap[pid] ?? 0;
        } else {
          // KES 2: Produk tak ada batch langsung (Legacy item).
          // Baru kita guna master stock.
          finalStock = productMasterStock;
        }

        int existingQty = pendingSalesMap[pid] ?? 0;
        bool isRisky = expiringTodayIds.contains(pid);

        tempList.add(ProductLocalState(
          id: pid,
          name: data['productName'] ?? 'Unknown',
          sku: data['barcodeNo']?.toString() ?? data['sku'] ?? '-',
          currentStock: finalStock, // Stok yang dah ditapis
          category: cat,
          price: price,
          imageUrl: data['imageUrl'] ?? data['image'],
          soldQty: existingQty,
          isExpiringToday: isRisky,
          hasBatches: productsWithBatches.contains(pid),
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
  // 2. AUTO GENERATE SALES (SKIP BARANG EXPIRED / ZERO STOCK)
  // ==========================================================
  void _randomizeAllSales() {
    final Random random = Random();
    int itemsUpdated = 0;

    setState(() {
      for (var product in _allProducts) {
        // Syarat:
        // 1. Stok mesti lebih dari 0 (Barang expired akan jadi 0 stok automatik dlm logic atas)
        // 2. Bukan barang yang expired hari ini (!product.isExpiringToday)
        if (product.currentStock > 0 && product.currentStock > product.soldQty && !product.isExpiringToday) {

          if (random.nextDouble() < 0.5) {
            int remaining = product.currentStock - product.soldQty;
            int maxToAdd = remaining > 5 ? 5 : remaining;
            int extraQty = random.nextInt(maxToAdd) + 1;
            product.soldQty += extraQty;
            itemsUpdated++;
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(itemsUpdated > 0 ? "Sales Generated! (Skipped expired items)" : "No eligible stock found."),
          backgroundColor: itemsUpdated > 0 ? primaryColor : Colors.orange,
          duration: const Duration(milliseconds: 1500),
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
      // Check stok sebelum tambah
      if (_allProducts[index].currentStock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item Expired or Out of Stock!"), backgroundColor: Colors.red)
        );
        return;
      }

      if (_allProducts[index].soldQty < _allProducts[index].currentStock) {
        setState(() {
          _allProducts[index].soldQty++;
          _selectedCategory = "All";
          _searchQuery = "";
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

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final batchWrite = FirebaseFirestore.instance.batch();
      final pendingRef = FirebaseFirestore.instance.collection('pending_sales');
      final now = Timestamp.now();

      for (var item in _cartItems) {
        var docRef = pendingRef.doc(item.id);

        batchWrite.set(docRef, {
          'productID': item.id,
          'userID': user.uid,
          'quantitySold': item.soldQty,
          'totalAmount': item.price * item.soldQty,
          'saleDate': now,
          'snapshotName': item.name,
          'imageUrl': item.imageUrl,
          'status': 'pending_deduction',
          'remarks': _remarksController.text.trim(),
        }, SetOptions(merge: true));
      }

      await batchWrite.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sales list updated in Stock Out!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // ==========================================================
  // UI UTAMA
  // ==========================================================
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 180),
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
            ],
          ),

          // LAYER 2: Draggable Bottom Sheet
          _buildDraggableBottomSummary(),
        ],
      ),
    );
  }

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

  Widget _buildDraggableBottomSummary() {
    return DraggableScrollableSheet(
      initialChildSize: 0.18,
      minChildSize: 0.18,
      maxChildSize: 0.75,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -5))]
          ),
          child: CustomScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Center(
                      child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 50, height: 6,
                          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Total Pending Sales (${_totalItemsSold})", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text("RM ${_totalSalesAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _saveToFirebase,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 5,
                            ),
                            child: const Text("Update List", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),

              if (_cartItems.isEmpty)
                const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Padding(padding: EdgeInsets.only(top: 20), child: Text("Swipe up to review list", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))))
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      if (index == _cartItems.length) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 300),
                          child: TextField(
                              controller: _remarksController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                  hintText: "Add remarks (optional)...",
                                  filled: true, fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                              )
                          ),
                        );
                      }

                      final item = _cartItems[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text("${item.soldQty}x", style: TextStyle(fontWeight: FontWeight.w900, color: primaryColor)),
                            ),
                            const SizedBox(width: 15),
                            Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                            Text("RM ${(item.price * item.soldQty).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                    childCount: _cartItems.length + 1,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// --- ITEM PRODUK LIST ---
class _ProductListItem extends StatelessWidget {
  final ProductLocalState product;
  final Function(int) onQtyChanged;
  const _ProductListItem({required this.product, required this.onQtyChanged});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF203288);
    // [LOGIC UI] Kalau stok 0 (sebab expired), disable butang tambah
    final bool isOutOfStock = product.currentStock <= 0;

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
          _buildProductImage(product.imageUrl, size: 55, primaryColor: primaryBlue),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if(product.isExpiringToday)
                Container(
                  margin: const EdgeInsets.only(left: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text("Exp Today", style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
              if(isOutOfStock)
                Container(
                  margin: const EdgeInsets.only(left: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text("Expired/No Stock", style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text("Stock: ${product.currentStock}", style: TextStyle(fontSize: 11, color: isOutOfStock ? Colors.red : Colors.grey.shade600, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text("RM ${product.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w900)),
            ]),
          ])),
          Row(children: [
            IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24),
                onPressed: () => onQtyChanged(max(0, product.soldQty - 1))
            ),
            Container(width: 30, alignment: Alignment.center, child: Text("${product.soldQty}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: product.soldQty > 0 ? primaryBlue : Colors.black))),
            IconButton(
                icon: Icon(Icons.add_circle_outline, color: isOutOfStock ? Colors.grey : Colors.green, size: 24),
                onPressed: isOutOfStock ? null : () => onQtyChanged(min(product.currentStock, product.soldQty + 1))
            ),
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