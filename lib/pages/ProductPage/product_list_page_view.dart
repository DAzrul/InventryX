import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Features_app/barcode_scanner_page.dart';

/// --------------------
/// Product List Item (Read-only)
/// --------------------
class ProductListItemReadOnly extends StatelessWidget {
  final String productName;
  final String category;
  final String subCategory;
  final String imageUrl;
  final double price;
  final int quantity;
  final String barcodeNo;
  final VoidCallback onTap;

  const ProductListItemReadOnly({
    super.key,
    required this.productName,
    required this.category,
    required this.subCategory,
    required this.price,
    required this.quantity,
    required this.barcodeNo,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 70,
                height: 70,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey.shade200,
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: imageUrl.isEmpty
                    ? const Icon(Icons.inventory_2, size: 30, color: Colors.black54)
                    : null,
              ),
              // Product Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$category • $subCategory',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.qr_code, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(barcodeNo,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stock: $quantity | RM ${price.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepPurple.shade700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// --------------------
/// Manager/Staff Product List Page (Read-only)
/// --------------------
class ProductListViewPage extends StatefulWidget {
  const ProductListViewPage({super.key});

  @override
  State<ProductListViewPage> createState() => _ProductListViewPageState();
}

class _ProductListViewPageState extends State<ProductListViewPage> {
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
    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
    String barcodeStr = (data['barcodeNo'] ?? '').toString();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Image
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade100,
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                        ? Image.network(
                      data['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _barcodePlaceholder(barcodeStr),
                    )
                        : _barcodePlaceholder(barcodeStr),
                  ),
                ),
                const SizedBox(height: 12),

                // Product Name
                Text(
                  data['productName'] ?? 'Unnamed',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Product Details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('Category', data['category']),
                    _detailRow('Subcategory', data['subCategory']),
                    _detailRow('Supplier', data['supplier'] ?? data['supplierId']),
                    _detailRow('Barcode', barcodeStr),
                    _detailRow('Stock', stock.toString()),
                    _detailRow('Price', 'RM ${data['price'] ?? 0.0}'),
                  ],
                ),
                const SizedBox(height: 16),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF233E99),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value ?? '-', style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _barcodePlaceholder(String barcodeNo) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code, size: 40, color: Colors.black38),
            if (barcodeNo.isNotEmpty)
              Text(
                barcodeNo,
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
          ],
        ),
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

                    double price = double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
                    int stock = int.tryParse(product['currentStock']?.toString() ?? '0') ?? 0;
                    String barcode = (product['barcodeNo'] ?? '').toString();

                    return ProductListItemReadOnly(
                      productName: product['productName'] ?? 'Unnamed',
                      category: product['category'] ?? '-',
                      subCategory: product['subCategory'] ?? '-',
                      price: price,
                      quantity: stock,
                      barcodeNo: barcode,
                      imageUrl: product['imageUrl'] ?? '',
                      onTap: () => _showProductDetails(context, product),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
