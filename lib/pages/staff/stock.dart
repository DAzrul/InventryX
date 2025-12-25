import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_incoming_stock.dart';
import 'stock_out.dart';
import '../Features_app/barcode_scanner_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  String selectedCategory = 'All';
  String searchQuery = ''; // Untuk menyimpan teks carian
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _scanBarcode() async {
    final scannedResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (scannedResult != null && scannedResult.isNotEmpty) {
      setState(() {
        searchQuery = scannedResult;
        _searchController.text = scannedResult;
      });
    }
  }

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

            // LOGIC KIRA SUMMARY (Kekal sama)
            int totalItems = allDocs.length;
            int outOfStock = 0;
            int lowStock = 0;

            for (var doc in allDocs) {
              final data = doc.data() as Map<String, dynamic>;
              int currentQty = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
              int reorder = int.tryParse(data['reorderLevel']?.toString() ?? '10') ?? 10;
              if (currentQty == 0) outOfStock++; else if (currentQty <= reorder) lowStock++;
            }

            // FILTER LIST IKUT CATEGORY & SEARCH QUERY
            final filteredDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['productName'] ?? '').toString().toLowerCase();
              final barcode = (data['barcodeNo'] ?? '').toString().toLowerCase();

              bool matchCategory = selectedCategory == 'All' || data['category'] == selectedCategory;
              bool matchSearch = name.contains(searchQuery.toLowerCase()) || barcode.contains(searchQuery.toLowerCase());

              return matchCategory && matchSearch;
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER (Kekal sama)
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text('Inventory Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SUMMARY CARD (Kekal sama)
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

                  // ACTION BUTTONS (Kekal sama)
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

                  // ===== BARU: SEARCH & SCANNER BAR =====
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() => searchQuery = value),
                            decoration: InputDecoration(
                              hintText: 'Search product...',
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                                _searchController.clear();
                                setState(() => searchQuery = '');
                              })
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _scanBarcode,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00147C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // CATEGORY FILTER
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'FOOD', 'BEVERAGES', 'PERSONAL CARE'].map((cat) => _categoryChip(cat)).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PRODUCT LIST (DENGAN FILTER SEARCH)
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? const Center(child: Text('No products found.'))
                        : ListView.builder(
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