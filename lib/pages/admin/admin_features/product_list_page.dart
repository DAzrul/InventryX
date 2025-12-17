// File: product_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_add_page.dart';
import 'product_edit_page.dart';
import 'product_delete_dialog.dart';
import 'barcode_scanner_page.dart'; // your scanner page

/// --------------------
/// Product List Item
/// --------------------
class ProductListItem extends StatelessWidget {
  final String productName;
  final String category;
  final String subCategory;
  final double price;
  final int quantity;
  final int barcodeNo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductListItem({
    super.key,
    required this.productName,
    required this.category,
    required this.subCategory,
    required this.price,
    required this.quantity,
    required this.barcodeNo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
            child: const Icon(Icons.qr_code, color: Colors.black54),
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

  /// 🔥 Product stream based on category
  Stream<QuerySnapshot> get _productStream {
    final collection = FirebaseFirestore.instance.collection("products");
    if (_selectedCategory == 'ALL') {
      return collection.snapshots();
    } else {
      return collection.where('category', isEqualTo: _selectedCategory).snapshots();
    }
  }

  /// Bottom nav
  void _onBottomNavTap(int index) {
    if (index == 1) return;
    if (index == 0 || index == 2) {
      Navigator.pop(context, index);
    }
  }

  /// Barcode scan search
  Future<void> scanBarcode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => BarcodeScannerPage()),
    );
    if (scanned != null) {
      setState(() {
        _searchText = scanned;
        _searchController.text = scanned;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: const Text(
            "Products",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 26,
              color: Colors.black,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Color(0xFF233E99), size: 30),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductAddPage()),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          /// 🔍 Search Bar with barcode button
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF233E99)),
                  onPressed: scanBarcode,
                ),
              ],
            ),
          ),

          /// Dashboard Card (Total Products)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF233E99),
                borderRadius: BorderRadius.circular(15),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection("products").snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length.toString() : '...';
                  return Row(
                    children: [
                      const Icon(Icons.inventory, color: Colors.white, size: 30),
                      const SizedBox(width: 10),
                      Text(
                        count,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "Total Products",
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          /// Category filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._categories.map((cat) {
                    final selected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF233E99) : Colors.grey.shade400,
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
                  }),
                ],
              ),
            ),
          ),

          /// Product List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No products found"));
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['productName'] ?? '').toString().toLowerCase();
                  final barcode = (data['barcodeNo'] ?? '').toString();
                  final searchText = _searchText.toLowerCase();
                  return name.contains(searchText) || barcode.contains(searchText);
                }).toList();

                if (docs.isEmpty) return const Center(child: Text("No matching products"));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final product = doc.data() as Map<String, dynamic>;
                    return ProductListItem(
                      productName: product['productName'] ?? '',
                      category: product['category'] ?? '',
                      subCategory: product['subCategory'] ?? '',
                      price: (product['price'] ?? 0).toDouble(),
                      quantity: product['quantity'] ?? 0,
                      barcodeNo: product['barcodeNo'] ?? 0,
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductEditPage(
                            productId: doc.id,
                            productData: product,
                          ),
                        ),
                      ),
                      onDelete: () async {
                        final deleted = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => ProductDeleteDialog(
                            productId: doc.id,
                            productData: product,
                          ),
                        );

                        if (deleted == true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Product deleted')),
                          );
                        }
                      },
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
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Features'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outlined), label: 'Profile'),
        ],
      ),
    );
  }
}
