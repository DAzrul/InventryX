// File: product_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'product_add_page.dart';
import 'product_edit_page.dart';
import 'product_delete_page.dart';

class ProductListItem extends StatelessWidget {
  final String productName;
  final String category;
  final String subCategory;
  final double price;
  final int quantity;
  final String? imageUrl;

  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ProductListItem({
    super.key,
    required this.productName,
    required this.category,
    required this.subCategory,
    required this.price,
    required this.quantity,
    this.imageUrl,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

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
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
            child: !hasImage
                ? const Icon(Icons.inventory, color: Colors.black54)
                : null,
          ),

          title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("$category • $subCategory\nStock: $quantity   Price: RM $price"),

          trailing: Row(
            mainAxisSize: MainAxisSize.min,
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
    );
  }
}

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  String _selectedCategory = 'ALL';

  final List<String> _categories = [
    'ALL',
    'FOOD',
    'BEVERAGES',
    'PERSONAL CARE',
  ];

  Stream<QuerySnapshot> get _productStream {
    Query collection = FirebaseFirestore.instance.collection("products");

    if (_selectedCategory == "ALL") {
      return collection.orderBy('productName').snapshots();
    } else {
      return collection.where('category', isEqualTo: _selectedCategory).snapshots();
    }
  }

  Future<int> _fetchTotalProductCount() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection("products").get();
    return snapshot.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: Text(
          "Products",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          /// Dashboard Card
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF233E99),
                borderRadius: BorderRadius.circular(15),
              ),
              child: FutureBuilder<int>(
                future: _fetchTotalProductCount(),
                builder: (context, snapshot) {
                  final String count = snapshot.data?.toString() ?? "...";

                  return Row(
                    children: [
                      const Icon(Icons.inventory, color: Colors.white, size: 30),
                      const SizedBox(width: 10),
                      Text(count,
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
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

          /// Category Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                ..._categories.map((cat) {
                  final bool selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF233E99) : Colors.grey.shade300,
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

                /// Add Product Button
                GestureDetector(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ProductAddPage())),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.add_box_outlined, color: Color(0xFF233E99)),
                  ),
                ),
              ],
            ),
          ),


          /// Product List (Stream)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No products found"));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final product = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;

                    return ProductListItem(
                      productName: product['productName'] ?? "Unknown",
                      category: product['category'] ?? "No Category",
                      subCategory: product['subCategory'] ?? "",
                      price: (product['price'] ?? 0).toDouble(),
                      quantity: product['quantity'] ?? 0,
                      imageUrl: product['imageUrl'],

                      onEdit: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProductEditPage(
                                productId: id,
                                productData: product,
                              ))),

                      onDelete: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProductDeletePage(
                                productId: id,
                                productData: product,
                              ))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Features'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
