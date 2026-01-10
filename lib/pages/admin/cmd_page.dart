import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Class untuk track state setiap produk semasa simulasi berjalan
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
  bool forceZeroStock;

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
    this.forceZeroStock = false,
  });
}

class LocalBatch {
  String batchId;
  String batchNumber;
  int currentQty;
  DocumentReference ref;

  LocalBatch(this.batchId, this.batchNumber, this.currentQty, this.ref);
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

  void _showMultiProductDialog() {
    _selectedProducts = [];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Pilih Produk (Multi-Select)"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 10), child: Text("Pilih produk untuk simulasi (Target Baki 20-50 & 5 Item Kosong).", style: TextStyle(fontSize: 12, color: Colors.grey))),
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
                  onPressed: _selectedProducts.isEmpty ? null : () { Navigator.pop(context); _runGlobalSimulation(); },
                  child: Text("Run Simulasi (${_selectedProducts.length} Items)", style: const TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _runGlobalSimulation() async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 20), Text("Generating Data until TODAY...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
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

        int minExp = 180; int maxExp = 365;
        if (pNameUpper.contains('ROTI') || pNameUpper.contains('GARDENIA') || pNameUpper.contains('BUN')) { minExp = 4; maxExp = 7; }
        else if (pNameUpper.contains('MILK') || pNameUpper.contains('SUSU')) { minExp = 30; maxExp = 60; }
        else if (cat.contains('BEVERAGES') || cat.contains('CANNED')) { minExp = 365; maxExp = 730; }

        simulationList.add(SimProduct(id: doc.id, data: data, name: pName, price: double.tryParse(data['price']?.toString() ?? '0.0') ?? 0.0, unitsPerCarton: int.tryParse(data['unitsPerCarton']?.toString() ?? '1') ?? 1, minExpiry: minExp, maxExpiry: maxExp, activeBatches: [], currentStock: 0, supplierName: pSupplierName, supplierId: pSupplierId));
      }

      // 🔥 LOGIC: SELECT 5 RANDOM PRODUCTS TO BE ZERO STOCK 🔥
      if (simulationList.length >= 5) {
        List<SimProduct> tempShuffle = List.from(simulationList)..shuffle();
        for (int i = 0; i < 5; i++) tempShuffle[i].forceZeroStock = true;
      } else if (simulationList.isNotEmpty) {
        simulationList[0].forceZeroStock = true;
      }

      // 🔥 LOGIC: SET DATE RANGE (UNTIL TODAY) 🔥
      DateTime today = DateTime.now();
      DateTime currentDate = today.subtract(const Duration(days: 180));
      int daysSinceLastRestock = 0;
      int globalRestockCount = 0;

      // --- B. LOOP 180 HARI (HINGGA HARI INI) ---
      // Loop selagi tarikh belum melepasi hari ini
      while (currentDate.isBefore(today) || currentDate.isAtSameMomentAs(today)) {

        currentDate = currentDate.add(const Duration(days: 1));
        if (currentDate.isAfter(today)) break; // Safety break

        daysSinceLastRestock++;

        // >>> LOGIC 1: SMART RESTOCK (STOP 15 HARI SEBELUM HARI INI) <<<
        // Kita stop restock 2 minggu sebelum hari ini supaya stok sempat susut secara natural
        bool stopRestockPhase = currentDate.isAfter(today.subtract(const Duration(days: 15)));
        bool isRestockDay = (daysSinceLastRestock > (7 + random.nextInt(3))) && !stopRestockPhase;

        // Force restock hari pertama
        if (simulationList.first.currentStock == 0 && globalRestockCount == 0) isRestockDay = true;

        if (isRestockDay) {
          daysSinceLastRestock = 0;
          globalRestockCount++;
          String dateStr = DateFormat('yyyyMMdd').format(currentDate);

          Map<String, List<SimProduct>> supplierGroups = {};
          for (var prod in simulationList) {
            if (!supplierGroups.containsKey(prod.supplierName)) supplierGroups[prod.supplierName] = [];
            supplierGroups[prod.supplierName]!.add(prod);
          }

          for (var entry in supplierGroups.entries) {
            String supplierName = entry.key;
            List<SimProduct> productsInLorry = entry.value;
            String supplierId = productsInLorry.first.supplierId;
            String globalStockInID = "SI-$dateStr-${random.nextInt(9999)}";
            DocumentReference stockInRef = db.collection('stockIn').doc(globalStockInID);
            int totalQtyInBatch = 0; int totalItemsInBatch = 0;

            for (var prod in productsInLorry) {
              // Volume restock sederhana
              int cartonsIn; int qtyIn;

              if (prod.unitsPerCarton == 1) {
                qtyIn = 20 + random.nextInt(10);
                cartonsIn = qtyIn;
              } else {
                cartonsIn = 2 + random.nextInt(3); // 2-4 karton
                qtyIn = cartonsIn * prod.unitsPerCarton;
              }

              prod.currentStock += qtyIn; totalQtyInBatch += qtyIn; totalItemsInBatch++;
              int daysToRot = prod.minExpiry + random.nextInt(prod.maxExpiry - prod.minExpiry + 1);
              DateTime expDate = currentDate.add(Duration(days: daysToRot));
              String batchNum = "BATCH-$dateStr-${random.nextInt(99999)}";

              DocumentReference itemRef = stockInRef.collection('items').doc();
              batch.set(itemRef, {'itemId': itemRef.id, 'productId': prod.id, 'productName': prod.name, 'batchNumber': batchNum, 'expiryDate': Timestamp.fromDate(expDate), 'quantity': qtyIn, 'cartons': cartonsIn});
              await checkBatchLimit();

              DocumentReference batchRef = db.collection('batches').doc();
              batch.set(batchRef, {'batchId': batchRef.id, 'batchNumber': batchNum, 'productId': prod.id, 'productName': prod.name, 'initialQuantity': qtyIn, 'currentQuantity': qtyIn, 'expiryDate': Timestamp.fromDate(expDate), 'receivedDate': Timestamp.fromDate(currentDate), 'status': 'active', 'supplierId': supplierId, 'supplierName': supplierName, 'createdAt': Timestamp.fromDate(currentDate), 'stockInId': globalStockInID});
              await checkBatchLimit();

              prod.activeBatches.add(LocalBatch(batchRef.id, batchNum, qtyIn, batchRef));

              DocumentReference moveRef = db.collection('stockMovements').doc();
              batch.set(moveRef, {'movementId': moveRef.id, 'productId': prod.id, 'productName': prod.name, 'quantity': qtyIn, 'type': 'Stock In', 'reason': 'Restock from $supplierName', 'refId': globalStockInID, 'timestamp': Timestamp.fromDate(currentDate), 'user': _fixedUserId});
              await checkBatchLimit();
            }
            batch.set(stockInRef, {'stockInId': globalStockInID, 'receivedDate': Timestamp.fromDate(currentDate), 'supplierId': supplierId, 'supplierName': supplierName, 'totalQuantity': totalQtyInBatch, 'totalItems': totalItemsInBatch, 'notes': 'Simulated Order from $supplierName', 'createdBy': _fixedUserId});
            await checkBatchLimit();
          }
        }

        // >>> LOGIC 2: SALES (HIGH FREQUENCY, SMALL QTY) <<<
        for (var prod in simulationList) {
          if (prod.currentStock > 0) {

            // Demand Calculation
            int minDemand = (prod.unitsPerCarton == 1) ? 5 : 15;
            int maxDemand = (prod.unitsPerCarton == 1) ? 15 : 60;
            if (prod.minExpiry < 10) { minDemand = 30; maxDemand = 80; }

            int totalDailyDemand = minDemand + random.nextInt(maxDemand - minDemand + 1);
            if (totalDailyDemand > prod.currentStock) totalDailyDemand = prod.currentStock;

            if (totalDailyDemand <= 0) continue;

            int remainingToSell = totalDailyDemand;

            // Generate multiple small transactions
            while (remainingToSell > 0) {
              int txQty = 1 + random.nextInt(10);
              if (txQty > remainingToSell) txQty = remainingToSell;

              prod.currentStock -= txQty;
              remainingToSell -= txQty;

              int remainingToDeductBatch = txQty;
              for (var b in prod.activeBatches) {
                if (remainingToDeductBatch <= 0) break;
                if (b.currentQty > 0) {
                  int take = min(b.currentQty, remainingToDeductBatch);
                  b.currentQty -= take;
                  remainingToDeductBatch -= take;
                }
              }

              int hour = 9 + random.nextInt(12);
              int minute = random.nextInt(60);
              DateTime txTime = DateTime(currentDate.year, currentDate.month, currentDate.day, hour, minute);

              DocumentReference saleRef = db.collection('sales').doc();
              batch.set(saleRef, {
                'salesID': saleRef.id, 'productID': prod.id, 'snapshotName': prod.name,
                'quantitySold': txQty, 'totalAmount': txQty * prod.price,
                'saleDate': Timestamp.fromDate(txTime), 'status': 'completed',
                'remarks': 'Walk-in Customer', 'userID': _fixedUserId
              });
              await checkBatchLimit();

              DocumentReference moveRef = db.collection('stockMovements').doc();
              batch.set(moveRef, {
                'movementId': moveRef.id, 'productId': prod.id, 'productName': prod.name,
                'quantity': -txQty, 'type': 'Sold', 'reason': 'Sales Order',
                'timestamp': Timestamp.fromDate(txTime), 'user': _fixedUserId
              });
              await checkBatchLimit();
            }
          }
        }

        // >>> LOGIC 3: RANDOM STOCK LOSS <<<
        for (var prod in simulationList) {
          if (prod.currentStock > 10 && random.nextDouble() < 0.05) {
            List<String> reasons = ['Expired', 'Damaged', 'Theft', 'Returned', 'Adjustment'];
            String reasonType = reasons[random.nextInt(reasons.length)];
            int lossQty = 1 + random.nextInt(3);
            if (lossQty > prod.currentStock) lossQty = prod.currentStock;

            prod.currentStock -= lossQty;
            int remainingToDeductBatch = lossQty;
            String affectedBatchId = "";
            String affectedBatchNum = "";

            for (var b in prod.activeBatches) {
              if (remainingToDeductBatch <= 0) break;
              if (b.currentQty > 0) {
                int take = min(b.currentQty, remainingToDeductBatch);
                b.currentQty -= take; remainingToDeductBatch -= take;
                affectedBatchId = b.batchId; affectedBatchNum = b.batchNumber;
              }
            }

            DocumentReference moveRef = db.collection('stockMovements').doc();
            batch.set(moveRef, {'movementId': moveRef.id, 'productId': prod.id, 'productName': prod.name, 'quantity': -lossQty, 'type': reasonType, 'reason': 'Manual Adjustment: $reasonType', 'timestamp': Timestamp.fromDate(currentDate.add(Duration(hours: 14))), 'user': _fixedUserId});
            await checkBatchLimit();

            if (reasonType == 'Expired' && affectedBatchId.isNotEmpty) {
              DocumentReference alertRef = db.collection('alerts').doc();
              batch.set(alertRef, {'alertType': 'expiry', 'batchId': affectedBatchId, 'batchNumber': affectedBatchNum, 'expiryStage': 'expired', 'isDone': true, 'isNotified': true, 'isRead': false, 'notifiedAt': Timestamp.fromDate(currentDate), 'productId': prod.id, 'productName': prod.name});
              await checkBatchLimit();
            }
          }
        }

      } // End Loop (Hingga Hari Ini)

      // >>> LOGIC 4: STRICT FINAL ADJUSTMENT (TARGET 20-50 & ZERO STOCK) <<<
      // Ini dijalankan selepas loop tamat (iaitu pada HARI INI)

      for (var prod in simulationList) {
        int targetStock;

        // 🔥 RULE 1: KES KHAS 5 PRODUK WAJIB 0 🔥
        if (prod.forceZeroStock) {
          targetStock = 0;
        }
        // 🔥 RULE 2: PRODUK LAIN WAJIB 20 - 50 🔥
        else {
          // Random antara 20 hingga 50
          targetStock = 20 + random.nextInt(31);
        }

        // Jika stok sekarang tak sama dengan target, kita adjust (Adjust UP atau DOWN)
        if (prod.currentStock != targetStock) {

          // Case A: Stok Terlebih (Kena Kurangkan)
          if (prod.currentStock > targetStock) {
            int qtyToClear = prod.currentStock - targetStock;
            prod.currentStock = targetStock;

            // FIFO Deduct
            int remainingToDeduct = qtyToClear;
            for (var b in prod.activeBatches) {
              if (remainingToDeduct <= 0) break;
              if (b.currentQty > 0) {
                int take = min(b.currentQty, remainingToDeduct);
                b.currentQty -= take;
                remainingToDeduct -= take;
              }
            }

            // Rekod Sales 'Clearance' pada hari ini
            DocumentReference saleRef = db.collection('sales').doc();
            batch.set(saleRef, {
              'salesID': saleRef.id, 'productID': prod.id, 'snapshotName': prod.name,
              'quantitySold': qtyToClear, 'totalAmount': qtyToClear * (prod.price * 0.5),
              'saleDate': Timestamp.now(),
              'status': 'completed',
              'remarks': 'System Balance Adjustment (Clearance)',
              'userID': _fixedUserId
            });
            await checkBatchLimit();

            DocumentReference moveRef = db.collection('stockMovements').doc();
            batch.set(moveRef, {
              'movementId': moveRef.id, 'productId': prod.id, 'productName': prod.name,
              'quantity': -qtyToClear, 'type': 'Sold', 'reason': 'Clearance Sale',
              'timestamp': Timestamp.now(), 'user': _fixedUserId
            });
            await checkBatchLimit();
          }

          // Case B: Stok Terkurang (Kena Tambah sikit - Jarang berlaku tapi safety net)
          else if (prod.currentStock < targetStock && !prod.forceZeroStock) {
            // Jika stok terlalu rendah (bawah 20), kita buat 'Emergency Restock' hari ini
            int qtyToAdd = targetStock - prod.currentStock;
            prod.currentStock = targetStock;

            String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
            String batchNum = "BATCH-$dateStr-ADJ";
            DateTime expDate = DateTime.now().add(const Duration(days: 180));

            DocumentReference batchRef = db.collection('batches').doc();
            batch.set(batchRef, {
              'batchId': batchRef.id, 'batchNumber': batchNum, 'productId': prod.id, 'productName': prod.name,
              'initialQuantity': qtyToAdd, 'currentQuantity': qtyToAdd, 'expiryDate': Timestamp.fromDate(expDate),
              'receivedDate': Timestamp.now(), 'status': 'active', 'supplierId': prod.supplierId, 'supplierName': prod.supplierName,
              'createdAt': Timestamp.now()
            });
            await checkBatchLimit();
            prod.activeBatches.add(LocalBatch(batchRef.id, batchNum, qtyToAdd, batchRef));

            DocumentReference moveRef = db.collection('stockMovements').doc();
            batch.set(moveRef, {
              'movementId': moveRef.id, 'productId': prod.id, 'productName': prod.name,
              'quantity': qtyToAdd, 'type': 'Stock In', 'reason': 'System Balance Adjustment (Topup)',
              'timestamp': Timestamp.now(), 'user': _fixedUserId
            });
            await checkBatchLimit();
          }
        }
      }

      // --- C. FINAL SYNC ---
      for (var prod in simulationList) {
        for (var b in prod.activeBatches) { batch.update(b.ref, {'currentQuantity': b.currentQty}); await checkBatchLimit(); }
        Map<String, dynamic> up = {'currentStock': prod.currentStock, 'updatedAt': Timestamp.now()};
        if (prod.data.containsKey('quantityInStock')) up['quantityInStock'] = prod.currentStock;
        batch.update(db.collection('products').doc(prod.id), up);
        await checkBatchLimit();
      }

      await batch.commit();
      if (mounted) { Navigator.pop(context); showDialog(context: context, builder: (_) => AlertDialog(title: const Text("Simulasi Selesai! ✅"), content: Text("Data berjaya dijana sehingga HARI INI.\n\nTarget Tercapai:\n- Majoriti Produk: 20-50 unit\n- 5 Produk Random: 0 unit"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))])); }

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
          const Text("Multi-product. High Frequency Sales.\nStrict Final Stock Target (20-50 & 0).", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          InkWell(onTap: _showMultiProductDialog, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Row(children: [const Icon(Icons.storefront_rounded, color: Colors.blueAccent, size: 30), const SizedBox(width: 15), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Run Realistic Simulation", style: TextStyle(fontWeight: FontWeight.bold)), Text("Full Suite: Until Today + Target Stock", style: TextStyle(fontSize: 11, color: Colors.grey))])), const Icon(Icons.chevron_right)]))),
        ]),
      ),
    );
  }
}