import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_add_page.dart';
import 'product_edit_page.dart';
import 'product_delete_dialog.dart';
import '../../Features_app/barcode_scanner_page.dart';

/// --------------------
/// Product List Item
/// --------------------
class ProductListItem extends StatelessWidget {
  final String productName;
  final String category;
  final String subCategory;
  final String imageUrl;
  final double price;
  final int quantity;
  final int barcodeNo;
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
      padding: const EdgeInsets.only(bottom: 10),
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
              backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : null,
              child: imageUrl == null || imageUrl.isEmpty
                  ? const Icon(Icons.qr_code, color: Colors.black54)
                  : null,
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
  int _currentIndex = 0;
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
    return collection
        .where('category', isEqualTo: _selectedCategory)
        .snapshots();
  }

  void _onBottomNavTap(int index) {
    if (index == 1) return;
    Navigator.pop(context, index);
  }

  Future<void> scanBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (scanned != null) {
      setState(() {
        _searchText = scanned;
        _searchController.text = scanned;
      });
    }
  }

  /// --------------------
  /// PRODUCT DETAIL POPUP
  /// --------------------
  void _showProductDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PRODUCT IMAGE (fits the image format, rounded corners)
              if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 4 / 3, // adjust box to image ratio
                    child: Image.network(
                      data['imageUrl'],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.image_not_supported)),
                      ),
                    ),
                  ),
                ),

              // DETAILS SECTION
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PRODUCT NAME
                    Text(
                      data['productName'] ?? "Unknown Product",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Category & Subcategory
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Category: ${data['category'] ?? '-'}"),
                        Text("Subcategory: ${data['subCategory'] ?? '-'}"),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Supplier
                    Text("Supplier: ${data['supplier'] ?? '-'}"),
                    const SizedBox(height: 6),

                    // Barcode & Stock
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Barcode: ${data['barcodeNo'] ?? '-'}"),
                        Text(
                          "Stock: ${data['quantity'] ?? 0}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (data['quantity'] ?? 0) > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Price
                    Text(
                      "Price: RM ${data['price']?.toStringAsFixed(2) ?? '0.00'}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF233E99),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // STOCK STATUS
                    Row(
                      children: [
                        const Text("Stock Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          (data['quantity'] ?? 0) > 0
                              ? "✅ Available"
                              : "❌ Out of stock",
                          style: TextStyle(
                            color: (data['quantity'] ?? 0) > 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // CLOSE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF233E99),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Close",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Text(
            "Products",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 26,
              color: Colors.black,
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          /// Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchText = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search product name or barcode...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner,
                      color: Color(0xFF233E99)),
                  onPressed: scanBarcode,
                ),
              ],
            ),
          ),

          /// Category filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF233E99)
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          /// Product list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                  (data['productName'] ?? '').toString().toLowerCase();
                  final barcode =
                  (data['barcodeNo'] ?? '').toString();
                  return name.contains(_searchText) ||
                      barcode.contains(_searchText);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text("No products found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final product =
                    doc.data() as Map<String, dynamic>;

                    return ProductListItem(
                      productName: product['productName'] ?? '',
                      category: product['category'] ?? '',
                      subCategory: product['subCategory'] ?? '',
                      price: (product['price'] ?? 0).toDouble(),
                      quantity: product['quantity'] ?? 0,
                      barcodeNo: product['barcodeNo'] ?? 0,
                      imageUrl: product['imageUrl'] ?? '',
                      onTap: () =>
                          _showProductDetails(context, product),
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductEditPage(
                            productId: doc.id,
                            productData: product,
                          ),
                        ),
                      ),
                      onDelete: () => showDialog(
                        context: context,
                        builder: (_) => ProductDeleteDialog(
                          productId: doc.id,
                          productData: product,
                        ),
                      ),
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
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductAddPage()),
          );
        },
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,



      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: 'Features'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined), label: 'Profile'),
        ],
      ),
    );
  }
}
