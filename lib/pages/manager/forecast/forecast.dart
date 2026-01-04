import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// IMPORT MODELS & PAGES
import 'package:inventryx/models/product_model.dart';
import 'package:inventryx/pages/manager/forecast/result_page.dart';
import 'package:inventryx/pages/manager/manager_page.dart';
import 'package:inventryx/pages/manager/utils/manager_features_modal.dart';
import 'package:inventryx/pages/Profile/User_profile_page.dart';

class ForecastingPage extends StatefulWidget {
  const ForecastingPage({super.key});

  @override
  State<ForecastingPage> createState() => _ForecastingPageState();
}

class _ForecastingPageState extends State<ForecastingPage> {
  // Index 1 sebab Forecast sebahagian dari Features
  int _selectedIndex = 1;

  String? selectedCategory;
  Map<String, int> selectedQuantities = {};

  final Color primaryColor = const Color(0xFF233E99);
  final Color bgGrey = const Color(0xFFF4F7FF);

  final Map<String, IconData> _categoryIconMap = {
    'Food': Icons.restaurant_menu_rounded,
    'Beverages': Icons.local_drink_rounded,
    'Personal Care': Icons.soap_rounded,
    'General': Icons.inventory_2_rounded,
  };

  @override
  void initState() {
    super.initState();
    // [PENTING] Load draft lama bila page dibuka
    _loadDraftFromFirebase();
  }

  // --- LOGIC 1: SAVE DRAFT ---
  Future<void> _saveDraftToFirebase() async {
    if (selectedQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nothing to save! Select items first."), backgroundColor: Colors.orange)
      );
      return;
    }

    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saving draft..."), duration: Duration(milliseconds: 800))
      );

      // Simpan data dalam collection 'forecast_drafts' ikut UID manager
      await FirebaseFirestore.instance.collection('forecast_drafts').doc(uid).set({
        'userId': uid,
        'selectedItems': selectedQuantities,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Draft saved successfully!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Error saving draft: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- LOGIC 2: LOAD DRAFT ---
  Future<void> _loadDraftFromFirebase() async {
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('forecast_drafts').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> savedItems = data['selectedItems'] ?? {};

        setState(() {
          // Convert Map<String, dynamic> ke Map<String, int>
          selectedQuantities = savedItems.map((key, value) => MapEntry(key, value as int));
        });

        if (mounted && selectedQuantities.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Previous draft loaded."),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              )
          );
        }
      }
    } catch (e) {
      debugPrint("Error loading draft: $e");
    }
  }

  // --- LOGIC 3: NAVIGATION ---
  void _onItemTapped(BuildContext context, int index, String currentUsername, String uid) {
    if (index == 0) {
      // Home: Reset App
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ManagerPage(
            loggedInUsername: currentUsername,
            userId: uid,
            username: '',
          ),
        ),
            (Route<dynamic> route) => false,
      );
    } else if (index == 1) {
      // Features: Buka Modal
      ManagerFeaturesModal.show(context, currentUsername, uid);
    } else if (index == 2) {
      // Profile: Tukar Tab
      setState(() => _selectedIndex = index);
    }
  }

  IconData _getCategoryIcon(String category) {
    for (var key in _categoryIconMap.keys) {
      if (key.toUpperCase() == category.toUpperCase()) {
        return _categoryIconMap[key]!;
      }
    }
    return Icons.category_rounded;
  }

  // --- BUILD UTAMA ---
  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          String currentUsername = "Manager";
          if (snapshot.hasData && snapshot.data!.exists) {
            var d = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = d['username'] ?? "Manager";
          }
          final safeUid = uid ?? '';

          return Scaffold(
            backgroundColor: bgGrey,
            extendBody: true,

            bottomNavigationBar: _buildFloatingNavBar(context, currentUsername, safeUid),

            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildForecastContent(),
                ProfilePage(username: currentUsername, userId: safeUid),
              ],
            ),
          );
        }
    );
  }

  // --- NAVBAR TERAPUNG ---
  Widget _buildFloatingNavBar(BuildContext context, String currentUsername, String uid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => _onItemTapped(context, index, currentUsername, uid),
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          items: [
            _navItem(Icons.home_outlined, Icons.home_rounded, "Home"),
            _navItem(Icons.grid_view_outlined, Icons.grid_view_rounded, "Features"),
            _navItem(Icons.person_outline_rounded, Icons.person_rounded, "Profile"),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData inactiveIcon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(
      icon: Icon(inactiveIcon, size: 22),
      activeIcon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(activeIcon, size: 22, color: primaryColor),
      ),
      label: label,
    );
  }

  // --- CONTENT FORECAST ---
  Widget _buildForecastContent() {
    return Column(
      children: [
        AppBar(
          title: const Text(
            "Demand Forecasting",
            style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w800, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: _buildCategoryTabs(categoriesList, allProducts),
                  ),
                  Expanded(
                    child: subCategoryMap.isEmpty
                        ? Center(child: Text("No items in $selectedCategory", style: TextStyle(color: Colors.grey[400])))
                        : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
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
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildCategoryTabs(List<String> categories, List<ProductModel> allProducts) {
    return SizedBox(
      height: 45,
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
                boxShadow: isSelected
                    ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(_getCategoryIcon(category), size: 18, color: isSelected ? Colors.white : Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(category, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                      child: Text("$badgeCount", style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: badgeCount > 0 ? primaryColor.withOpacity(0.5) : Colors.transparent, width: 1.5),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: bgGrey, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.folder_open_rounded, color: primaryColor, size: 20),
                  ),
                  const Spacer(),
                  Text(subCategoryName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1C1E)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text("${products.length} Products", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (displayImage.isNotEmpty)
              Positioned(
                bottom: -10, right: -10,
                child: Opacity(
                  opacity: 0.1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(displayImage, width: 80, height: 80, fit: BoxFit.cover),
                  ),
                ),
              ),
            if (badgeCount > 0)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                  child: Text("$badgeCount Selected", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.08), offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _saveDraftToFirebase, // [FIX] Guna function save sebenar
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text("Save Draft", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (selectedQuantities.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one product"), backgroundColor: Colors.red));
                  return;
                }
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
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 5,
                shadowColor: primaryColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_graph_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text("Forecast Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  void _showProductSelectionDialog(String title, List<ProductModel> products) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(20),
                height: 600,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text("Select products to include in forecast", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 20),
                    Expanded(
                      child: GridView.builder(
                        itemCount: products.length,
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12
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
                                  selectedQuantities[product.id] = 1;
                                }
                                setState(() {});
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
                                border: Border.all(
                                    color: isSelected ? primaryColor : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: product.imageUrl.isNotEmpty
                                              ? Image.network(product.imageUrl, fit: BoxFit.contain)
                                              : Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade300),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
                                        child: Text(
                                            product.name,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected ? primaryColor : Colors.black87
                                            )
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 8, right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                                      ),
                                    )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0
                        ),
                        child: const Text("Confirm Selection", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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