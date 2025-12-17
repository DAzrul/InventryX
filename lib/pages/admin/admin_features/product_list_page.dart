import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'product_add_page.dart';
import 'product_edit_page.dart';
import 'product_delete_page.dart';

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
    final bool outOfStock = quantity <= 0;

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

  /// 🔥 FIXED QUERY (NO orderBy)
  Stream<QuerySnapshot> get _productStream {
    final collection = FirebaseFirestore.instance.collection("products");

    if (_selectedCategory == 'ALL') {
      return collection.snapshots();
    } else {
      return collection
          .where('category', isEqualTo: _selectedCategory)
          .snapshots();
    }
  }

  void _onBottomNavTap(int index) {
    if (index == 1) return;
    if (index == 0 || index == 2) {
      Navigator.pop(context, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// AppBar
      appBar: AppBar(
        title: const Text("Products", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          /// 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
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

          /// Dashboard Card (REAL-TIME)
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
                  final count = snapshot.hasData
                      ? snapshot.data!.docs.length.toString()
                      : '...';

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

          /// Category Filters + Add Button
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
                  }),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProductAddPage()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_box_outlined,
                          color: Color(0xFF233E99)),
                    ),
                  ),
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

                  // Search by name OR barcode
                  return name.contains(searchText) || barcode.contains(searchText);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text("No matching products"));
                }

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
                      onDelete: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDeletePage(
                            productId: doc.id,
                            productData: product,
                          ),
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
