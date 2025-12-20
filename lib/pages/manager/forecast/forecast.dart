import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ForecastingPage extends StatefulWidget {
  const ForecastingPage({super.key});

  @override
  State<ForecastingPage> createState() => _ForecastingPageState();
}

class _ForecastingPageState extends State<ForecastingPage> {
  // STATE VARIABLES
  String? selectedCategory;

  // Tracks selected products quantity: Key = ProductID, Value = Quantity
  Map<String, int> selectedQuantities = {};

  // Hardcoded Icons to match your wireframe exactly
  final Map<String, IconData> _categoryIconMap = {
    'Food': Icons.restaurant_menu,
    'Beverages': Icons.local_drink,
    'Personal Care': Icons.soap,
    'General': Icons.inventory_2_outlined,
  };

  // Helper: Get Icon based on category name
  IconData _getCategoryIcon(String category) {
    for (var key in _categoryIconMap.keys) {
      if (key.toUpperCase() == category.toUpperCase()) {
        return _categoryIconMap[key]!;
      }
    }
    return Icons.category_outlined;
  }

  // Helper: Count selected items inside a specific Category for the badge
  int _getCategoryBadgeCount(String category, List<ProductModel> allProducts) {
    int count = 0;
    for (var product in allProducts) {
      if (product.category == category && selectedQuantities.containsKey(product.id)) {
        count++;
      }
    }
    return count;
  }

  // Helper: Count selected items inside a specific SubCategory for the badge
  int _getSubCategoryBadgeCount(String subCategory, List<ProductModel> allProducts) {
    int count = 0;
    for (var product in allProducts) {
      if (product.subCategory == subCategory && selectedQuantities.containsKey(product.id)) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      // 1. APP BAR
      appBar: AppBar(
        title: const Text("Forecast", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),

      // 2. BOTTOM NAVIGATION BAR (Footer)
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        currentIndex: 1, // 'Features' is active
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Features"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),

      // 3. BODY CONTENT
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error loading data"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          // A. Process Data
          final allProducts = snapshot.data!.docs.map((doc) {
            return ProductModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          // B. Get Categories & Sort Logic
          Set<String> uniqueCategories = allProducts.map((p) => p.category).toSet();
          List<String> categoriesList = uniqueCategories.toList();

          // SORTING: Force "Food" to be first, then alphabetical
          categoriesList.sort((a, b) {
            if (a == 'Food') return -1;
            if (b == 'Food') return 1;
            return a.compareTo(b);
          });

          // C. Set Default Tab (Logic: If nothing selected, select the first one)
          if (selectedCategory == null && categoriesList.isNotEmpty) {
            selectedCategory = categoriesList.first;
          }

          // D. Filter Products for Current Tab
          final productsInCurrentTab = allProducts
              .where((p) => p.category == selectedCategory)
              .toList();

          // E. Group by SubCategory
          Map<String, List<ProductModel>> subCategoryMap = {};
          for (var p in productsInCurrentTab) {
            if (!subCategoryMap.containsKey(p.subCategory)) {
              subCategoryMap[p.subCategory] = [];
            }
            subCategoryMap[p.subCategory]!.add(p);
          }

          return Column(
            children: [
              // --- TOP TABS ---
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildCategoryTabs(categoriesList, allProducts),
              ),

              // --- SUBCATEGORY GRID ---
              Expanded(
                child: subCategoryMap.isEmpty
                    ? Center(child: Text("No items in $selectedCategory"))
                    : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: subCategoryMap.length,
                  itemBuilder: (context, index) {
                    String subCatName = subCategoryMap.keys.elementAt(index);
                    List<ProductModel> products = subCategoryMap[subCatName]!;
                    return _buildSubCategoryCard(subCatName, products, allProducts);
                  },
                ),
              ),

              // --- ACTION BUTTONS (Pinned above Footer) ---
              _buildActionButtons(),
            ],
          );
        },
      ),
    );
  }

  // ===============================================
  // WIDGET: Top Category Tabs
  // ===============================================
  Widget _buildCategoryTabs(List<String> categories, List<ProductModel> allProducts) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          // LOGIC: Check if this tab matches the currently selected category
          final isSelected = category == selectedCategory;

          final int badgeCount = _getCategoryBadgeCount(category, allProducts);

          return GestureDetector(
            onTap: () => setState(() => selectedCategory = category),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              decoration: BoxDecoration(
                // COLOR LOGIC: Blue if selected, White if not
                color: isSelected ? const Color(0xFF233E99) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))] : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      _getCategoryIcon(category),
                      size: 18,
                      // ICON COLOR: White if selected, Black if not
                      color: isSelected ? Colors.white : Colors.black87
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: TextStyle(
                      // TEXT COLOR: White if selected, Black if not
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  // PILL BADGE
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CA0FF), // Lighter Blue for the pill
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$badgeCount items",
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
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
  // WIDGET: SubCategory Card
  // ===============================================
  Widget _buildSubCategoryCard(String subCategoryName, List<ProductModel> products, List<ProductModel> allProducts) {
    String displayImage = products.isNotEmpty ? products.first.imageUrl : '';
    int badgeCount = _getSubCategoryBadgeCount(subCategoryName, allProducts);

    return GestureDetector(
      onTap: () => _showProductSelectionDialog(subCategoryName, products),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    subCategoryName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Image
                  Expanded(
                    child: Center(
                      child: displayImage.isNotEmpty
                          ? Image.network(displayImage, fit: BoxFit.contain)
                          : const Icon(Icons.folder_open, size: 40, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            // Badge (Top Right)
            if (badgeCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CA0FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$badgeCount items",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===============================================
  // WIDGET: Action Buttons (Right Aligned)
  // ===============================================
  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end, // <--- PUSHES BUTTONS TO THE RIGHT
        children: [
          // SAVE BUTTON
          SizedBox(
            width: 200, // Compact width
            height: 40,
            child: ElevatedButton(
              onPressed: () {
                if (selectedQuantities.isEmpty) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selections Saved!")));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF233E99),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),

          const SizedBox(height: 10),

          // GENERATE BUTTON
          SizedBox(
            width: 200, // Matches Save button width
            height: 40,
            child: ElevatedButton(
              onPressed: () {
                // Navigate logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF233E99),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text("Generate Forecast", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
  // ===============================================
  // DIALOG: Product Selection (Popup)
  // ===============================================
  void _showProductSelectionDialog(String title, List<ProductModel> products) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 550,
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        const SizedBox(width: 48), // Balance for centering
                      ],
                    ),
                    const Divider(),

                    // Grid
                    Expanded(
                      child: GridView.builder(
                        itemCount: products.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (ctx, i) {
                          final product = products[i];
                          final isSelected = selectedQuantities.containsKey(product.id);

                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selectedQuantities.remove(product.id);
                                } else {
                                  selectedQuantities[product.id] = 1; // Default qty 1
                                }
                                setState(() {}); // Refresh main page badges
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: product.imageUrl.isNotEmpty
                                              ? Image.network(product.imageUrl, fit: BoxFit.contain)
                                              : const Icon(Icons.inventory_2, size: 40),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          product.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                  // CHECKBOX
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      height: 22, width: 22,
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF233E99) : Colors.white,
                                        border: Border.all(color: isSelected ? const Color(0xFF233E99) : Colors.grey.shade400),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                                          : null,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF233E99),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Done", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ===============================================
// HELPER MODEL
// ===============================================
class ProductModel {
  final String id;
  final String name;
  final String category;
  final String subCategory;
  final String imageUrl;
  final double price;

  ProductModel({required this.id, required this.name, required this.category, required this.subCategory, required this.imageUrl, required this.price});

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['productName'] ?? 'Unknown',
      category: map['category'] ?? 'General',
      subCategory: map['subCategory'] ?? 'General',
      imageUrl: map['imageUrl'] ?? '',
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] ?? 0.0),
    );
  }
}