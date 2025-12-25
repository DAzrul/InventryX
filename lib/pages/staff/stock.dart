import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_incoming_stock.dart';
import 'stock_out.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  String selectedCategory = 'All';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('products').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Ada error la mat!'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final allDocs = snapshot.data!.docs;

            // LOGIC KIRA SUMMARY
            int totalItems = allDocs.length;
            int outOfStock = 0;
            int lowStock = 0;

            for (var doc in allDocs) {
              final data = doc.data() as Map<String, dynamic>;
              int currentQty = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
              int reorder = int.tryParse(data['reorderLevel']?.toString() ?? '10') ?? 10;

              if (currentQty == 0) {
                outOfStock++;
              } else if (currentQty <= reorder) {
                lowStock++;
              }
            }

            // FILTER LIST IKUT CATEGORY
            final filteredDocs = selectedCategory == 'All'
                ? allDocs
                : allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['category'] == selectedCategory).toList();

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text('Inventory Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),

                  // ===== SUMMARY CARD (AUTO-CALCULATED) =====
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SummaryItem(value: '$totalItems', label: 'Total Items', color: Colors.indigo),
                        _SummaryItem(value: '$lowStock', label: 'Low Stock', color: Colors.orange),
                        _SummaryItem(value: '$outOfStock', label: 'Out of Stock', color: Colors.red),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== ACTION BUTTONS (CONNECTED) =====
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00147C),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: const Text('Stock In', style: TextStyle(color: Colors.white)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddIncomingStockPage())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.upload, color: Colors.red),
                          label: const Text('Stock Out', style: TextStyle(color: Colors.red)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockOutPage())),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // ===== CATEGORY FILTER (DYNAMIC) =====
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'FOOD', 'BEVERAGES', 'PERSONAL CARE'].map((cat) => _categoryChip(cat)).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== PRODUCT LIST (REAL-TIME FROM FIREBASE) =====
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index].data() as Map<String, dynamic>;
                        int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
                        String imgUrl = data['imageUrl'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(color: const Color(0xFFF0F2F6), borderRadius: BorderRadius.circular(10)),
                                child: imgUrl.isNotEmpty
                                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(imgUrl, fit: BoxFit.cover))
                                    : const Icon(Icons.inventory_2, color: Colors.indigo),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['productName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(data['barcodeNo']?.toString() ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('$stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: stock <= 10 ? Colors.red : Colors.indigo)),
                                  Text(data['unit'] ?? 'pcs', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
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
        ),
      ),
    );
  }

  Widget _categoryChip(String label) {
    final bool isSelected = selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF00147C),
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        onSelected: (_) => setState(() => selectedCategory = label),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _SummaryItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}