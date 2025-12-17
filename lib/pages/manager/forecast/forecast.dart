import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForecastingPage extends StatefulWidget {
  const ForecastingPage({super.key});

  @override
  State<ForecastingPage> createState() => _ForecastingPageState();
}

class _ForecastingPageState extends State<ForecastingPage> {
  // We don't need a hardcoded List<String> anymore!
  // We only track what the user currently clicked.
  String? selectedCategory;

  // Stores selected products. Key = ProductID, Value = Product Data
  Map<String, ProductModel> selectedProducts = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Forecast", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      // MOVED STREAMBUILDER TO TOP: Fetches data before drawing ANY UI
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error loading data"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          // 1. CONVERT ALL DATA
          final allProducts = snapshot.data!.docs.map((doc) {
            return ProductModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          // 2. EXTRACT UNIQUE CATEGORIES DYNAMICALLY
          // We look at every product and collect the 'category' names
          Set<String> uniqueCategories = allProducts.map((p) => p.category).toSet();
          List<String> categoriesList = uniqueCategories.toList()..sort();

          // 3. SET DEFAULT TAB (If none selected, pick the first one found)
          if (selectedCategory == null && categoriesList.isNotEmpty) {
            selectedCategory = categoriesList.first;
          }

          return Column(
            children: [
              // PASS DYNAMIC CATEGORIES TO THE TABS WIDGET
              _buildCategoryTabs(categoriesList, allProducts),

              // PASS PRODUCTS TO THE LIST WIDGET
              Expanded(
                child: _buildProductList(allProducts),
              ),

              _buildBottomBar(),
            ],
          );
        },
      ),
    );
  }

  // ===============================================
  // WIDGET: Category Tabs (Now with Dynamic Images!)
  // ===============================================
  Widget _buildCategoryTabs(List<String> categories, List<ProductModel> allProducts) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          // 1. SMART LOGIC: Find the first product in this category to use as the icon
          // We use .firstWhere to find a match, or return null if empty
          final ProductModel? firstProduct = allProducts
              .cast<ProductModel?>() // Helper cast to allow returning null
              .firstWhere(
                  (p) => p!.category == category && p.imageUrl.isNotEmpty,
              orElse: () => null
          );

          // Count items (for the badge)
          final count = selectedProducts.values.where((p) => p.category == category).length;

          return GestureDetector(
            onTap: () => setState(() => selectedCategory = category),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8), // Adjusted padding for image
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[900] : Colors.grey[200],
                borderRadius: BorderRadius.circular(30), // Pill shape
              ),
              child: Row(
                children: [
                  // 2. DISPLAY THE IMAGE (Circle Avatar style)
                  if (firstProduct != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                              image: NetworkImage(firstProduct.imageUrl),
                              fit: BoxFit.cover
                          )
                      ),
                    )
                  else
                  // Fallback Icon if no product has an image
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.category, size: 20, color: Colors.grey),
                    ),

                  // Category Name
                  Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),

                  // Count Badge
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$count",
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    )
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===============================================
  // WIDGET: Product List (Grouped by SubCategory)
  // ===============================================
  Widget _buildProductList(List<ProductModel> allProducts) {
    // 1. Filter by Current Category Tab
    final filteredProducts = allProducts.where((p) =>
    p.category == selectedCategory
    ).toList();

    if (filteredProducts.isEmpty) {
      return Center(child: Text("No items in $selectedCategory"));
    }

    // 2. GROUP BY SUBCATEGORY (e.g. { "Bakery": [Bread, Cake], "Snack": [Chips] })
    Map<String, List<ProductModel>> groupedProducts = {};
    for (var p in filteredProducts) {
      if (!groupedProducts.containsKey(p.subCategory)) {
        groupedProducts[p.subCategory] = [];
      }
      groupedProducts[p.subCategory]!.add(p);
    }

    // 3. Build List with Headers
    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupedProducts.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER: SubCategory Name (e.g., "Coffee & Tea")
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                entry.key,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            ),
            // GRID: Products in this SubCategory
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: entry.value.length,
              itemBuilder: (ctx, i) {
                final product = entry.value[i];
                final isSelected = selectedProducts.containsKey(product.id);
                return _buildProductCard(product, isSelected);
              },
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProductCard(ProductModel product, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedProducts.remove(product.id);
          } else {
            selectedProducts[product.id] = product;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: isSelected ? 2 : 1
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Use network image if available, else icon
            product.imageUrl.isNotEmpty
                ? Image.network(product.imageUrl, height: 40, errorBuilder: (_,__,___) => const Icon(Icons.error))
                : const Icon(Icons.inventory_2, size: 30, color: Colors.orange),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                product.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 16)
          ],
        ),
      ),
    );
  }

  // ===============================================
  // WIDGET: Bottom Action Bar
  // ===============================================
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)],
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {
            if (selectedProducts.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select items first!")));
              return;
            }
            // Navigate to Result Page (We will code this next)
            print("Moving to Results with: ${selectedProducts.keys}");
          },
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.blue.shade900),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12)
          ),
          child: Text("Generate Forecast", style: TextStyle(color: Colors.blue[900])),
        ),
      ),
    );
  }
}

// ===============================================
// HELPER MODEL: Updated to match your Screenshot
// ===============================================
class ProductModel {
  final String id;
  final String name;
  final String category;
  final String subCategory; // NEW
  final String imageUrl;    // NEW (saw this in your screenshot)
  final double price;

  ProductModel({required this.id, required this.name, required this.category, required this.subCategory, required this.imageUrl, required this.price});

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['productName'] ?? 'Unknown',
      category: map['category'] ?? 'Other',
      subCategory: map['subCategory'] ?? 'General',
      imageUrl: map['imageUrl'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
    );
  }
}