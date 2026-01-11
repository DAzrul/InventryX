import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SimProduct {
  String id;
  Map<String, dynamic> data;
  int currentStock;
  List<LocalBatch> activeBatches;
  String name;
  double price;
  int unitsPerCarton;
  int minExpiry;
  int maxExpiry;
  String supplierName;
  String supplierId;

  // Logic Baru: Target stok akhir
  bool isLowStockTarget; // Target 1-9 unit

  SimProduct({
    required this.id,
    required this.data,
    this.currentStock = 0,
    required this.activeBatches,
    required this.name,
    required this.price,
    required this.unitsPerCarton,
    required this.minExpiry,
    required this.maxExpiry,
    required this.supplierName,
    required this.supplierId,
    this.isLowStockTarget = false,
  });
}

class LocalBatch {
  String batchId;
  String batchNumber;
  int currentQty;
  DateTime expiryDate; // Track expiry date in memory
  DocumentReference ref;

  LocalBatch(this.batchId, this.batchNumber, this.currentQty, this.expiryDate, this.ref);
}

class CmdPage extends StatefulWidget {
  const CmdPage({super.key});

  @override
  State<CmdPage> createState() => _CmdPageState();
}

class _CmdPageState extends State<CmdPage> {
  final Color primaryBlue = const Color(0xFF233E99);
  final String _fixedUserId = "oaAHJjN3zmhJrUrlcILD2udCToj1";

  List<DocumentSnapshot> _selectedProducts = [];

  // Helper untuk buang masa (00:00:00) supaya date compare tepat
  DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  void _showMultiProductDialog() {
    _selectedProducts = [];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Pilih Produk (Balanced Sales RM1k-3k)"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 10), child: Text("Simulasi RM1000-RM3000 sehari. Baki 10-30 unit. Data hingga HARI INI.", style: TextStyle(fontSize: 12, color: Colors.grey))),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('products').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          final allProducts = snapshot.data?.docs ?? [];
                          if (allProducts.isEmpty) return const Text("Tiada produk.");
                          bool isAllSelected = _selectedProducts.length == allProducts.length;

                          return Column(
                            children: [
                              Container(
                                color: Colors.grey.withOpacity(0.1),
                                child: CheckboxListTile(
                                  activeColor: primaryBlue,
                                  title: const Text("Select All Products", style: TextStyle(fontWeight: FontWeight.bold)),
                                  value: isAllSelected,
                                  onChanged: (bool? value) {
                                    setStateDialog(() {
                                      if (value == true) _selectedProducts = List.from(allProducts);
                                      else _selectedProducts = [];
                                    });
                                  },
                                ),
                              ),
                              const Divider(height: 1, thickness: 1),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: allProducts.length,
                                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final doc = allProducts[i];
                                    final data = doc.data() as Map<String, dynamic>;
                                    final isSelected = _selectedProducts.any((p) => p.id == doc.id);
                                    String suppName = data['supplier'] ?? 'No Supplier';
                                    return CheckboxListTile(
                                      activeColor: primaryBlue,
                                      title: Text(data['productName'] ?? '-', style: const TextStyle(fontSize: 14)),
                                      subtitle: Text("Supplier: $suppName"),
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        setStateDialog(() {
                                          if (value == true) _selectedProducts.add(doc);
                                          else _selectedProducts.removeWhere((p) => p.id == doc.id);
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                  onPressed: _selectedProducts.isEmpty ? null : () { Navigator.pop(context); _runBalancedSimulation(); },
                  child: Text("Run Simulasi (${_selectedProducts.length} Items)", style: const TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _runBalancedSimulation() async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 20), Text("Generating Balanced Ecosystem...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
    );

    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      final Random random = Random();
      WriteBatch batch = db.batch();
      int operationCount = 0;

      Future<void> checkBatchLimit() async {
        operationCount++;
        if (operationCount >= 450) { await batch.commit(); batch = db.batch(); operationCount = 0; }
      }

      // --- A. INITIALIZE STATE ---
      List<SimProduct> simulationList = [];
      for (var doc in _selectedProducts) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String pName = data['productName'] ?? 'Unknown';
        String pNameUpper = pName.toUpperCase();
        String cat = (data['category'] ?? '').toString().toUpperCase();
        String pSupplierName = data['supplier'] ?? 'Unknown Supplier';
        String pSupplierId = data['supplierId'] ?? 'unknown_supp_id';
        int upc = int.tryParse(data['unitsPerCarton']?.toString() ?? '1') ?? 1;

        int minExp = 180; int maxExp = 365;
        if (upc == 1 || pNameUpper.contains('ROTI') || pNameUpper.contains('GARDENIA') || pNameUpper.contains('BUN')) { minExp = 3; maxExp = 7; }
        else if (pNameUpper.contains('MILK') || pNameUpper.contains('SUSU')) { minExp = 14; maxExp = 30; }
        else if (cat.contains('BEVERAGES') || cat.contains('CANNED')) { minExp = 365; maxExp = 730; }

        simulationList.add(SimProduct(id: doc.id, data: data, name: pName, price: double.tryParse(data['price']?.toString() ?? '0.0') ?? 0.0, unitsPerCarton: upc, minExpiry: minExp, maxExpiry: maxExp, activeBatches: [], currentStock: 0, supplierName: pSupplierName, supplierId: pSupplierId));
      }

      // 🔥 SELECT 5 PRODUCTS FOR LOW STOCK (1-9 UNITS) 🔥
      if (simulationList.length >= 5) {
        List<SimProduct> tempShuffle = List.from(simulationList)..shuffle();
        for (int i = 0; i < 5; i++) tempShuffle[i].isLowStockTarget = true;
      } else if (simulationList.isNotEmpty) {
        simulationList[0].isLowStockTarget = true;
      }

      DateTime today = normalizeDate(DateTime.now());
      DateTime currentDate = today.subtract(const Duration(days: 180));
      int daysSinceLastRestock = 0;

      // --- B. LOOP 180 HARI (DAY-BY-DAY) ---
      while (!currentDate.isAfter(today)) {

        daysSinceLastRestock++;
        bool isLastDay = currentDate.isAtSameMomentAs(today);

        // >>> PHASE 1: RESTOCK CHECK (Untuk Semua Produk) <<<
        // Restock jika stok < 100 atau setiap 7-9 hari.
        // Penting: Kita restock banyak supaya boleh support sales tinggi.
        bool forceRestockDay = (daysSinceLastRestock > (7 + random.nextInt(3)));

        if (forceRestockDay) {
          daysSinceLastRestock = 0;
          String dateStr = DateFormat('yyyyMMdd').format(currentDate);

          // Group by supplier
          Map<String, List<SimProduct>> supplierGroups = {};
          for (var p in simulationList) {
            // Logic restock: Kalau stok dah banyak (>300), tak payah restock hari ni, kecuali Roti (sebab expired cepat)
            if (p.currentStock > 300 && p.unitsPerCarton > 1) continue;

            if (!supplierGroups.containsKey(p.supplierName)) supplierGroups[p.supplierName] = [];
            supplierGroups[p.supplierName]!.add(p);
          }

          for (var entry in supplierGroups.entries) {
            String supplierName = entry.key;
            List<SimProduct> prods = entry.value;
            String globalStockInID = "SI-$dateStr-${random.nextInt(9999)}";
            DocumentReference stockInRef = db.collection('stockIn').doc(globalStockInID);
            int totalQty = 0; int totalItems = 0;

            for (var prod in prods) {
              int qtyIn; int cartonsIn;
              // Restock Aggressive: 100 - 300 unit
              if (prod.unitsPerCarton == 1) { qtyIn = 150 + random.nextInt(150); cartonsIn = qtyIn; }
              else { cartonsIn = 5 + random.nextInt(10); qtyIn = cartonsIn * prod.unitsPerCarton; }

              prod.currentStock += qtyIn; totalQty += qtyIn; totalItems++;

              // Smart Expiry (Based on Current Loop Date)
              int daysToRot = prod.minExpiry + random.nextInt(prod.maxExpiry - prod.minExpiry + 1);
              DateTime expDate = currentDate.add(Duration(days: daysToRot));
              String batchNum = "BATCH-$dateStr-${random.nextInt(99999)}";

              DocumentReference batchRef = db.collection('batches').doc();
              batch.set(batchRef, {'batchId': batchRef.id, 'batchNumber': batchNum, 'productId': prod.id, 'productName': prod.name, 'initialQuantity': qtyIn, 'currentQuantity': qtyIn, 'expiryDate': Timestamp.fromDate(expDate), 'receivedDate': Timestamp.fromDate(currentDate), 'status': 'active', 'supplierId': prod.supplierId, 'supplierName': prod.supplierName, 'createdAt': Timestamp.fromDate(currentDate), 'stockInId': globalStockInID});
              await checkBatchLimit();
              prod.activeBatches.add(LocalBatch(batchRef.id, batchNum, qtyIn, expDate, batchRef));

              batch.set(stockInRef.collection('items').doc(), {'productId': prod.id, 'productName': prod.name, 'batchNumber': batchNum, 'expiryDate': Timestamp.fromDate(expDate), 'quantity': qtyIn, 'cartons': cartonsIn});
              await checkBatchLimit();

              // Movement
              batch.set(db.collection('stockMovements').doc(), {'movementId': db.collection('stockMovements').doc().id, 'productId': prod.id, 'productName': prod.name, 'quantity': qtyIn, 'type': 'Stock In', 'reason': 'Restock $supplierName', 'refId': globalStockInID, 'timestamp': Timestamp.fromDate(currentDate), 'user': _fixedUserId});
              await checkBatchLimit();
            }
            batch.set(stockInRef, {'stockInId': globalStockInID, 'receivedDate': Timestamp.fromDate(currentDate), 'supplierId': prods.first.supplierId, 'supplierName': supplierName, 'totalQuantity': totalQty, 'totalItems': totalItems, 'notes': 'Simulated Restock', 'createdBy': _fixedUserId});
            await checkBatchLimit();
          }
        }

        // >>> PHASE 2: TARGETED SALES (RM 1000 - RM 3000 Daily) <<<
        double dailyTargetRevenue = 1000.0 + random.nextInt(2001); // Random RM1000 - RM3000
        double currentDailyRevenue = 0.0;
        int productsSoldTodayCount = 0;

        // Shuffle product list daily to be fair
        List<SimProduct> dailyProducts = List.from(simulationList)..shuffle();

        for (var prod in dailyProducts) {
          // Stop if revenue target hit AND we sold at least 10 types of products
          if (currentDailyRevenue >= dailyTargetRevenue && productsSoldTodayCount >= 10) break;

          if (prod.currentStock > 0) {
            // Jualan per produk: 10 - 50 unit (Supaya stok bergerak laju)
            int qtyToSell = 10 + random.nextInt(41);
            if (qtyToSell > prod.currentStock) qtyToSell = prod.currentStock;

            // Harga check
            double salesValue = qtyToSell * prod.price;
            if (salesValue == 0) salesValue = qtyToSell * 5.0; // Fallback price

            // Tolak Stock
            prod.currentStock -= qtyToSell;
            currentDailyRevenue += salesValue;
            productsSoldTodayCount++;

            // FIFO Deduct
            int remainingToDeduct = qtyToSell;
            for (var b in prod.activeBatches) {
              if (remainingToDeduct <= 0) break;
              if (b.currentQty > 0) {
                int take = min(b.currentQty, remainingToDeduct);
                b.currentQty -= take; remainingToDeduct -= take;
              }
            }

            // Generate Receipt (1 Transaction per product per day to save writes, but representing multiple customers)
            DateTime txTime = currentDate.add(Duration(hours: 9 + random.nextInt(12))); // 9am - 9pm

            DocumentReference saleRef = db.collection('sales').doc();
            batch.set(saleRef, {'salesID': saleRef.id, 'productID': prod.id, 'snapshotName': prod.name, 'quantitySold': qtyToSell, 'totalAmount': salesValue, 'saleDate': Timestamp.fromDate(txTime), 'status': 'completed', 'remarks': 'Walk-in Customers (Aggregated)', 'userID': _fixedUserId});
            await checkBatchLimit();

            batch.set(db.collection('stockMovements').doc(), {'movementId': db.collection('stockMovements').doc().id, 'productId': prod.id, 'productName': prod.name, 'quantity': -qtyToSell, 'type': 'Sold', 'reason': 'Sales Order', 'timestamp': Timestamp.fromDate(txTime), 'user': _fixedUserId});
            await checkBatchLimit();
          }
        }

        // >>> PHASE 3: RANDOM LOSS <<<
        for (var prod in simulationList) {
          if (prod.currentStock > 20 && random.nextDouble() < 0.05) {
            int loss = 1 + random.nextInt(3);
            prod.currentStock -= loss;
            // FIFO logic repeated...
            int rem = loss;
            for (var b in prod.activeBatches) { if(rem<=0)break; if(b.currentQty>0){ int t=min(b.currentQty, rem); b.currentQty-=t; rem-=t; } }

            batch.set(db.collection('stockMovements').doc(), {'movementId': db.collection('stockMovements').doc().id, 'productId': prod.id, 'productName': prod.name, 'quantity': -loss, 'type': 'Damaged', 'reason': 'Manual Adj', 'timestamp': Timestamp.fromDate(currentDate.add(const Duration(hours: 18))), 'user': _fixedUserId});
            await checkBatchLimit();
          }
        }

        currentDate = currentDate.add(const Duration(days: 1));
      } // End Daily Loop

      // >>> PHASE 4: FINAL ADJUSTMENT (FORCE TARGET STOCK AT END) <<<
      // Ini dijalankan selepas loop tamat (iaitu pada HARI INI)

      for (var prod in simulationList) {
        int targetStock;

        // 1. Determine Target
        if (prod.isLowStockTarget) {
          targetStock = 1 + random.nextInt(9); // 1 - 9 Unit (Tak kosong)
        } else {
          targetStock = 10 + random.nextInt(21); // 10 - 30 Unit
        }

        // 2. Adjust Stock
        if (prod.currentStock != targetStock) {

          // A. Terlebih Stok -> Buat Clearance
          if (prod.currentStock > targetStock) {
            int diff = prod.currentStock - targetStock;
            prod.currentStock = targetStock;

            // FIFO deduct
            int rem = diff;
            for (var b in prod.activeBatches) { if(rem<=0)break; if(b.currentQty>0){ int t=min(b.currentQty, rem); b.currentQty-=t; rem-=t; } }

            batch.set(db.collection('stockMovements').doc(), {'movementId': db.collection('stockMovements').doc().id, 'productId': prod.id, 'productName': prod.name, 'quantity': -diff, 'type': 'Sold', 'reason': 'Clearance Sale (Sim)', 'timestamp': Timestamp.now(), 'user': _fixedUserId});
            await checkBatchLimit();
          }

          // B. Terkurang Stok -> Buat Topup (Important for Freshness)
          else if (prod.currentStock < targetStock) {
            int diff = targetStock - prod.currentStock;
            prod.currentStock = targetStock;

            // 🔥 FRESHNESS LOGIC 🔥
            // Kalau topup hari ini, pastikan expiry date logik.
            // Roti: Expired 4 hari lagi. Barang lain: 6 bulan.
            int daysToLive = (prod.unitsPerCarton == 1) ? (3 + random.nextInt(3)) : 180;
            DateTime freshExp = DateTime.now().add(Duration(days: daysToLive));

            String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
            String batchNum = "BATCH-$dateStr-ADJ";

            DocumentReference batchRef = db.collection('batches').doc();
            batch.set(batchRef, {'batchId': batchRef.id, 'batchNumber': batchNum, 'productId': prod.id, 'productName': prod.name, 'initialQuantity': diff, 'currentQuantity': diff, 'expiryDate': Timestamp.fromDate(freshExp), 'receivedDate': Timestamp.now(), 'status': 'active', 'supplierId': prod.supplierId, 'supplierName': prod.supplierName, 'createdAt': Timestamp.now()});
            await checkBatchLimit();

            prod.activeBatches.add(LocalBatch(batchRef.id, batchNum, diff, freshExp, batchRef));

            batch.set(db.collection('stockMovements').doc(), {'movementId': db.collection('stockMovements').doc().id, 'productId': prod.id, 'productName': prod.name, 'quantity': diff, 'type': 'Stock In', 'reason': 'System Topup (Sim)', 'timestamp': Timestamp.now(), 'user': _fixedUserId});
            await checkBatchLimit();
          }
        }
      }

      // --- C. FINAL COMMIT TO DB ---
      for (var prod in simulationList) {
        for (var b in prod.activeBatches) { batch.update(b.ref, {'currentQuantity': b.currentQty}); await checkBatchLimit(); }
        Map<String, dynamic> up = {'currentStock': prod.currentStock, 'updatedAt': Timestamp.now()};
        if (prod.data.containsKey('quantityInStock')) up['quantityInStock'] = prod.currentStock;
        batch.update(db.collection('products').doc(prod.id), up);
        await checkBatchLimit();
      }

      await batch.commit();
      if (mounted) { Navigator.pop(context); showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Simulasi Selesai! ✅"), content: Text("Data berjaya dijana.\n\n- Sales Harian: RM1k - RM3k\n- Date: Hingga ${DateFormat('dd/MM/yyyy').format(DateTime.now())}\n- Baki Akhir: 10-30 unit (Low: 1-9)\n- Expiry: Roti Fresh (3-5 hari)."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))])); }

    } catch (e) { if (mounted) Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(title: const Text("CMD & Utilities", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Text("Global Ecosystem Generator", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Balanced Revenue (RM1k-3k). \nAccurate until TODAY. \nSmart Final Stock (10-30 & Low <10).", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          InkWell(onTap: _showMultiProductDialog, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Row(children: [const Icon(Icons.storefront_rounded, color: Colors.blueAccent, size: 30), const SizedBox(width: 15), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Run Balanced Simulation", style: TextStyle(fontWeight: FontWeight.bold)), Text("Full Suite: Until Today + Revenue Target", style: TextStyle(fontSize: 11, color: Colors.grey))])), const Icon(Icons.chevron_right)]))),
        ]),
      ),
    );
  }
}