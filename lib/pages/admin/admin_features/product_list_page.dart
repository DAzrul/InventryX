import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_add_page.dart';
import 'product_edit_page.dart';
import 'product_delete_dialog.dart';
import '../../Features_app/barcode_scanner_page.dart';

/// --------------------
/// Product List Item (Dah Fix Subtype Error)
/// --------------------
class ProductListItem extends StatelessWidget {
  final String productName;
  final String category;
  final String subCategory;
  final String imageUrl;
  final double price;
  final int quantity; // Tetap int tapi kita hantar data yang dah di-parse
  final String barcodeNo; // TUKAR KEPADA STRING SUPAYA TAK ERROR
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ProductListItem({
    super.key,
    required this.productName,
    required this.category,
    required this.subCategory,
    required this.price,
    required this.quantity,
    required this.barcodeNo,
    required this.imageUrl,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty ? const Icon(Icons.inventory_2, color: Colors.black54) : null,
            ),
            title: Text(
              productName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "$category • $subCategory\n"
                  "Barcode: $barcodeNo\n"
                  "Stock: $quantity   Price: RM ${price.toStringAsFixed(2)}",
            ),
            trailing: SizedBox(
              width: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// --------------------
/// Product List Page
/// --------------------
class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  String _selectedCategory = 'ALL';
  int _currentIndex = 1; // Features index
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'ALL',
    'FOOD',
    'BEVERAGES',
    'PERSONAL CARE',
  ];

  Stream<QuerySnapshot> get _productStream {
    final collection = FirebaseFirestore.instance.collection("products");
    if (_selectedCategory == 'ALL') {
      return collection.snapshots();
    }
    return collection.where('category', isEqualTo: _selectedCategory).snapshots();
  }

  void _onBottomNavTap(int index) {
    setState(() => _currentIndex = index);
    // Tambah logic navigation kau kat sini kalau perlu
  }

  Future<void> scanBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (scanned != null) {
      setState(() {
        _searchText = scanned.toLowerCase();
        _searchController.text = scanned;
      });
    }
  }

  void _showProductDetails(BuildContext context, Map<String, dynamic> data) {
    // Parse data siap-siap elak popup crash
    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
    String barcodeStr = (data['barcodeNo'] ?? '').toString();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(data['imageUrl'], height: 200, fit: BoxFit.cover),
                )
              else
                const Icon(Icons.qr_code, size: 100, color: Colors.grey),
              const SizedBox(height: 16),
              Text(data['productName'] ?? 'Unnamed', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              _detailRow('Category', data['category']),
              _detailRow('Subcategory', data['subCategory']),
              _detailRow('Supplier', data['supplier'] ?? data['supplierId']),
              _detailRow('Barcode', barcodeStr),
              _detailRow('Stock', stock.toString()),
              _detailRow('Price', 'RM ${data['price'] ?? 0.0}'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF233E99)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? '-')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Products", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: Colors.black)),
      ),
      body: Column(
        children: [
          /// Search Bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchText = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Search name or barcode...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF233E99)),
                  onPressed: scanBarcode,
                ),
              ],
            ),
          ),

          /// Category Filter
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: _categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF233E99) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(cat, style: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          /// Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['productName'] ?? '').toString().toLowerCase();
                  final barcode = (data['barcodeNo'] ?? '').toString();
                  return name.contains(_searchText) || barcode.contains(_searchText);
                }).toList();

                if (filteredDocs.isEmpty) return const Center(child: Text("No products found"));

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final product = doc.data() as Map<String, dynamic>;

                    // --- LOGIC CONVERSION SUPAYA TAK SUBTYPE ERROR ---
                    double price = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
                    int stock = int.tryParse(product['currentStock']?.toString() ?? '0') ?? 0;
                    String barcode = (product['barcodeNo'] ?? '').toString();

                    return ProductListItem(
                      productName: product['productName'] ?? 'Unnamed',
                      category: product['category'] ?? '-',
                      subCategory: product['subCategory'] ?? '-',
                      price: price,
                      quantity: stock, // Ngam dengan schema currentStock
                      barcodeNo: barcode,
                      imageUrl: product['imageUrl'] ?? '',
                      onTap: () => _showProductDetails(context, product),
                      onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditPage(productId: doc.id, productData: product))),
                      onDelete: () => showDialog(context: context, builder: (_) => ProductDeleteDialog(productId: doc.id, productData: product)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF233E99),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductAddPage())),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        selectedItemColor: const Color(0xFF233E99),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Features'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}