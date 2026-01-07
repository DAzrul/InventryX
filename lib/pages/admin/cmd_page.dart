import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CmdPage extends StatefulWidget {
  const CmdPage({super.key});

  @override
  State<CmdPage> createState() => _CmdPageState();
}

class _CmdPageState extends State<CmdPage> {
  final Color primaryBlue = const Color(0xFF233E99);

  // HARDCODED VALUES (Ikut Request)
  final String _fixedUserId = "oaAHJjN3zmhJrUrlcILD2udCToj1";
  final String _fixedSupplierId = "laVxU835iX8D7mkoF9OJ";
  final String _fixedSupplierName = "DailyNeeds Trading";
  final String _salesRemarks = "Auto-deducted from pending list";

  // ===========================================================================
  // FUNGSI SIMULASI: GENERATE DATA SEBIJIK MACAM GAMBAR
  // ===========================================================================
  Future<void> _runFullCycleSimulation() async {
    // 1. Tunjuk Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      final Random random = Random();
      final WriteBatch batch = db.batch();

      // ---------------------------------------------------------
      // LANGKAH 1: PILIH PRODUK
      // ---------------------------------------------------------
      final productSnap = await db.collection('products').limit(1).get();

      if (productSnap.docs.isEmpty) {
        throw "Tiada produk dijumpai dalam database!";
      }

      final productDoc = productSnap.docs.first;
      final String productId = productDoc.id; // Ini ID document asal
      final Map<String, dynamic> productData = productDoc.data();
      final String productName = productData['productName'] ?? 'Unknown Product';

      // Parsing harga
      double price = 0.0;
      if (productData['price'] != null) {
        price = double.tryParse(productData['price'].toString()) ?? 0.0;
      }

      // Reset stok dalam minda
      int simulatedStock = 0;

      // Tarikh Mula: 60 Hari lepas
      DateTime currentDate = DateTime.now().subtract(const Duration(days: 60));

      // ---------------------------------------------------------
      // LANGKAH 2: BUAT STOCK IN (MULA-MULA)
      // ---------------------------------------------------------
      int initialStockIn = 200;
      simulatedStock += initialStockIn;

      DocumentReference stockInRef = db.collection('stockIn').doc();
      DocumentReference batchRef = db.collection('batches').doc();

      // Batch Number Format: BATCH-YYYYMMDD-RANDOM
      String dateStr = "${currentDate.year}${currentDate.month.toString().padLeft(2,'0')}${currentDate.day.toString().padLeft(2,'0')}";
      String batchNum = "BATCH-$dateStr-${random.nextInt(999999)}";

      // A. Masuk Table StockIn (Ikut Spec)
      batch.set(stockInRef, {
        'stockInId': stockInRef.id,
        'receivedDate': Timestamp.fromDate(currentDate),
        'supplierId': _fixedSupplierId,
        'supplierName': _fixedSupplierName,
        'totalQuantity': initialStockIn,
        'totalItems': 1,
        'notes': '', // Ikut gambar kosong string
        'createdBy': _fixedUserId,
      });

      // B. Masuk Table Batches (Ikut Spec)
      batch.set(batchRef, {
        'batchId': batchRef.id,
        'batchNumber': batchNum,
        'productId': productId,
        'productName': productName,
        'initialQuantity': initialStockIn,
        'currentQuantity': initialStockIn,
        'expiryDate': Timestamp.fromDate(currentDate.add(const Duration(days: 365))),
        'receivedDate': Timestamp.fromDate(currentDate),
        'createdAt': Timestamp.fromDate(currentDate),
        'status': 'active',
        'supplierId': _fixedSupplierId,
        'supplierName': _fixedSupplierName
      });

      // C. Masuk Table StockMovements (IN) (Ikut Spec)
      DocumentReference movementRefIn = db.collection('stockMovements').doc();
      batch.set(movementRefIn, {
        'movementId': movementRefIn.id,
        'productId': productId,
        'productName': productName,
        'quantity': initialStockIn,
        'type': 'Restock', // Atau 'In', ikut logic app you utk restock
        'reason': 'Stock In', // Simple reason
        'timestamp': Timestamp.fromDate(currentDate),
        'user': _fixedUserId
      });

      // ---------------------------------------------------------
      // LANGKAH 3: GENERATE SALES & MOVEMENT SETIAP HARI
      // ---------------------------------------------------------

      int totalSold = 0;

      for (int i = 0; i < 60; i++) {
        currentDate = currentDate.add(const Duration(days: 1));

        // Kebarangkalian Jualan (70%)
        if (random.nextDouble() > 0.3 && simulatedStock > 5) {

          int qtySold = random.nextInt(5) + 1;
          simulatedStock -= qtySold;
          totalSold += qtySold;
          double totalAmt = qtySold * price;

          DocumentReference saleRef = db.collection('sales').doc();
          DocumentReference moveRef = db.collection('stockMovements').doc();

          // D. Masuk Table Sales (Ikut Spec Tepat)
          batch.set(saleRef, {
            'salesID': saleRef.id,
            'productID': productId, // Huruf besar 'ID' ikut request
            'snapshotName': productName,
            'quantitySold': qtySold,
            'totalAmount': totalAmt, // number
            'saleDate': Timestamp.fromDate(currentDate.add(Duration(hours: 9 + random.nextInt(8)))),
            'status': 'completed',
            'remarks': _salesRemarks, // "Auto-deducted from pending list"
            'userID': _fixedUserId
          });

          // E. Masuk Table StockMovements (OUT - SOLD) (Ikut Spec Tepat)
          batch.set(moveRef, {
            'movementId': moveRef.id,
            'productId': productId, // Huruf kecil 'Id' ikut request
            'productName': productName,
            'quantity': -qtySold, // Negatif
            'type': 'Sold',
            'reason': 'Sales Order Completed',
            'timestamp': Timestamp.fromDate(currentDate),
            'user': _fixedUserId
          });
        }

        // F. Simulate Expired (Sekali sekala - 5% chance)
        // Ikut Spec Alerts
        if (random.nextDouble() < 0.05 && simulatedStock > 0) {
          int dmgQty = 1;
          simulatedStock -= dmgQty;

          DocumentReference alertRef = db.collection('alerts').doc();
          DocumentReference moveRef = db.collection('stockMovements').doc();

          // Movement for Damage/Expired
          batch.set(moveRef, {
            'movementId': moveRef.id,
            'productId': productId,
            'productName': productName,
            'quantity': -dmgQty,
            'type': 'Expired',
            'reason': 'Expired Check',
            'timestamp': Timestamp.fromDate(currentDate),
            'user': _fixedUserId
          });

          // Alert Record (Ikut Spec)
          batch.set(alertRef, {
            'alertType': 'expiry',
            'batchId': batchRef.id,
            'batchNumber': batchNum, // Added batchNumber
            'expiryStage': 'expired',
            'isDone': true,
            'isNotified': true,
            'isRead': false,
            'notifiedAt': Timestamp.fromDate(currentDate),
            'productId': productId,
            'productName': productName
          });
        }
      }

      // ---------------------------------------------------------
      // LANGKAH 4: UPDATE DATA INDUK (PEMBAIKAN STOK)
      // ---------------------------------------------------------

      // 1. Update Batch Baki Akhir
      batch.update(batchRef, {
        'currentQuantity': initialStockIn - totalSold
      });

      // 2. Update Product (Ikut request: Tak ubah structure, cuma update value)
      // Update dua-dua field supaya sync
      Map<String, dynamic> productUpdateData = {
        'currentStock': simulatedStock,
      };

      if (productData.containsKey('quantityInStock')) {
        productUpdateData['quantityInStock'] = simulatedStock;
      }

      // Tambah updatedAt timestamp
      productUpdateData['updatedAt'] = Timestamp.now();

      batch.update(productDoc.reference, productUpdateData);

      // ---------------------------------------------------------
      // LANGKAH 5: COMMIT
      // ---------------------------------------------------------
      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Tutup Loading

        showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Simulasi Berjaya! 🎉"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Produk: $productName", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text("• Supplier: $_fixedSupplierName"),
                    Text("• User ID: ...${_fixedUserId.substring(_fixedUserId.length - 6)}"),
                    const Divider(),
                    Text("• Stok Awal: $initialStockIn"),
                    Text("• Jualan: $totalSold"),
                    Text("• Baki Akhir: $simulatedStock", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
            )
        );
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("CMD & Utilities", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "System Generators",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E)),
            ),
            const SizedBox(height: 10),
            const Text(
              "Generate dummy data that EXACTLY matches your database schema.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            InkWell(
              onTap: _runFullCycleSimulation,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_circle_fill_rounded, color: Colors.green, size: 28),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Run Exact Schema Simulation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text("Generates 60 days of data using specific userIDs, remarks & field names.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}