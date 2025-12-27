import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// IMPORT SHARED MODEL
import 'package:inventryx/models/product_model.dart';
// LINK TO RESULT PAGE
import 'package:inventryx/pages/manager/forecast/result_page.dart';

class ForecastingPage extends StatefulWidget {
  const ForecastingPage({super.key});

  @override
  State<ForecastingPage> createState() => _ForecastingPageState();
}

class _ForecastingPageState extends State<ForecastingPage> {
  String? selectedCategory;
  Map<String, int> selectedQuantities = {};

  final Map<String, IconData> _categoryIconMap = {
    'Food': Icons.restaurant_menu,
    'Beverages': Icons.local_drink,
    'Personal Care': Icons.soap,
    'General': Icons.inventory_2_outlined,
  };

  IconData _getCategoryIcon(String category) {
    for (var key in _categoryIconMap.keys) {
      if (key.toUpperCase() == category.toUpperCase()) {
        return _categoryIconMap[key]!;
      }
    }
    return Icons.category_outlined;
  }

  int _getCategoryBadgeCount(String category, List<ProductModel> allProducts) {
    int count = 0;
    for (var product in allProducts) {
      if (product.category == category && selectedQuantities.containsKey(product.id)) {
        count++;
      }
    }
    return count;
  }

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
      appBar: AppBar(
        title: const Text("Forecast", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF233E99),
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Features"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error loading data"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final allProducts = snapshot.data!.docs.map((doc) {
            return ProductModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          Set<String> uniqueCategories = allProducts.map((p) => p.category).toSet();
          List<String> categoriesList = uniqueCategories.toList();

          categoriesList.sort((a, b) {
            if (a == 'Food') return -1;
            if (b == 'Food') return 1;
            return a.compareTo(b);
          });

          if (selectedCategory == null && categoriesList.isNotEmpty) {
            selectedCategory = categoriesList.first;
          }

          final productsInCurrentTab = allProducts
              .where((p) => p.category == selectedCategory)
              .toList();

          Map<String, List<ProductModel>> subCategoryMap = {};
          for (var p in productsInCurrentTab) {
            if (!subCategoryMap.containsKey(p.subCategory)) {
              subCategoryMap[p.subCategory] = [];
            }
            subCategoryMap[p.subCategory]!.add(p);
          }

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildCategoryTabs(categoriesList, allProducts),
              ),
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
              _buildActionButtons(allProducts),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryTabs(List<String> categories, List<ProductModel> allProducts) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          final int badgeCount = _getCategoryBadgeCount(category, allProducts);

          return GestureDetector(
            onTap: () => setState(() => selectedCategory = category),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF233E99) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(_getCategoryIcon(category), size: 18, color: isSelected ? Colors.white : Colors.black87),
                  const SizedBox(width: 8),
                  Text(category, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF4CA0FF), borderRadius: BorderRadius.circular(10)),
                      child: Text("$badgeCount items", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildSubCategoryCard(String subCategoryName, List<ProductModel> products, List<ProductModel> allProducts) {
    String displayImage = products.isNotEmpty ? products.first.imageUrl : '';
    int badgeCount = _getSubCategoryBadgeCount(subCategoryName, allProducts);

    return GestureDetector(
      onTap: () => _showProductSelectionDialog(subCategoryName, products),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          // Updated to use withValues if on newer Flutter, or keep withOpacity if older
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subCategoryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
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
            if (badgeCount > 0)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF4CA0FF), borderRadius: BorderRadius.circular(12)),
                  child: Text("$badgeCount items", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(List<ProductModel> allProducts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 200, height: 40,
            child: ElevatedButton(
              onPressed: () {
                if (selectedQuantities.isEmpty) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selections Saved!")));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF233E99), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 200, height: 40,
            child: ElevatedButton(
              onPressed: () {
                if (selectedQuantities.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one product")));
                  return;
                }
                // NAVIGATION: Pass data to Result Page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultPage(
                      selectedQuantities: selectedQuantities,
                      allProducts: allProducts,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF233E99), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text("Generate Forecast", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

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
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: GridView.builder(
                        itemCount: products.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
                        itemBuilder: (ctx, i) {
                          final product = products[i];
                          final isSelected = selectedQuantities.containsKey(product.id);
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selectedQuantities.remove(product.id);
                                } else {
                                  selectedQuantities[product.id] = 1;
                                }
                                setState(() {});
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: product.imageUrl.isNotEmpty ? Image.network(product.imageUrl, fit: BoxFit.contain) : const Icon(Icons.inventory_2, size: 40),
                                        ),
                                      ),
                                      Text(product.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                  Positioned(
                                    top: 8, right: 8,
                                    child: Container(
                                      height: 22, width: 22,
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF233E99) : Colors.white,
                                        border: Border.all(color: isSelected ? const Color(0xFF233E99) : Colors.grey.shade400),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
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
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF233E99), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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