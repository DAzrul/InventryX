import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import manager page
import '../manager/manager_page.dart';
import '../Features_app/barcode_scanner_page.dart';
import '../manager/utils/manager_features_modal.dart';
import '../Profile/User_profile_page.dart';

class ProductListViewPage extends StatefulWidget {
  const ProductListViewPage({super.key});

  @override
  State<ProductListViewPage> createState() => _ProductListViewPageState();
}

class _ProductListViewPageState extends State<ProductListViewPage> {
  int _selectedIndex = 1;
  String _searchText = '';
  String _selectedCategory = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  final Color primaryColor = const Color(0xFF203288);
  final List<String> _categories = ['ALL', 'FOOD', 'BEVERAGES', 'PERSONAL CARE'];

  void _onItemTapped(BuildContext context, int index, String currentUsername, String uid) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ManagerPage(
            loggedInUsername: currentUsername,
            userId: uid, username: '',
          ),
        ),
            (Route<dynamic> route) => false,
      );
    } else if (index == 1) {
      ManagerFeaturesModal.show(context, currentUsername, uid);
    } else if (index == 2) {
      setState(() => _selectedIndex = index);
    }
  }

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
          backgroundColor: const Color(0xFFF6F8FB),
          extendBody: true,
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: _buildFloatingNavBar(context, currentUsername, safeUid),
          body: IndexedStack(
            index: _selectedIndex == 2 ? 1 : 0,
            children: [
              _buildInventoryHome(),
              ProfilePage(username: currentUsername, userId: safeUid),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingNavBar(BuildContext context, String currentUsername, String uid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
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
        decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(activeIcon, size: 22, color: primaryColor),
      ),
      label: label,
    );
  }

  Widget _buildInventoryHome() {
    return Column(children: [_buildTopHeader(), _buildCategoryFilters(), _buildProductList()]);
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Products", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFFF5F7FB), borderRadius: BorderRadius.circular(18)),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchText = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search items...",
                  prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              final scanned = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
              if (scanned != null) setState(() { _searchText = scanned; _searchController.text = scanned; });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSel = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSel ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSel ? Colors.transparent : Colors.grey.shade200),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(color: isSel ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: (_selectedCategory == 'ALL')
            ? FirebaseFirestore.instance.collection("products").snapshots()
            : FirebaseFirestore.instance.collection("products").where('category', isEqualTo: _selectedCategory).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.where((d) => d['productName'].toString().toLowerCase().contains(_searchText)).toList();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildProductCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> data) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final isTablet = screenWidth >= 600;
    final double imgSize = isTablet ? 70 : isSmall ? 45 : 55;

    double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;
    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;

    // --- [UPDATED LOGIC] REORDER LEVEL ---
    int reorderLevel = int.tryParse(data['reorderLevel']?.toString() ?? '10') ?? 10;
    bool isLowStock = stock <= reorderLevel;

    return GestureDetector(
      onTap: () => _showProductDetailDialog(data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                  ? CachedNetworkImage(
                imageUrl: data['imageUrl'],
                width: imgSize,
                height: imgSize,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildPlaceholder(imgSize),
                errorWidget: (_, __, ___) => _buildPlaceholder(imgSize),
              )
                  : _buildPlaceholder(imgSize),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['productName'] ?? 'N/A',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: isTablet ? 16 : 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('RM ${price.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: isTablet ? 14 : 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      const SizedBox(width: 8),
                      // --- [UPDATED UI] STOCK ALERT ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isLowStock ? Colors.red.withOpacity(0.1) : primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Stock: $stock',
                            style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w900,
                                color: isLowStock ? Colors.red : primaryColor
                            )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryColor.withOpacity(0.1), width: 1.5),
      ),
      child: Center(
        child: Icon(Icons.inventory_2_rounded, color: primaryColor.withOpacity(0.3), size: size * 0.5),
      ),
    );
  }

  void _showProductDetailDialog(Map<String, dynamic> data) {
    double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;
    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
    int reorderLevel = int.tryParse(data['reorderLevel']?.toString() ?? '10') ?? 10;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.info_outline_rounded, color: primaryColor, size: 40),
                ),
                const SizedBox(height: 16),
                const Text("Product Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(children: [
                    Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: SizedBox(
                          width: 70,
                          height: 70,
                          child: (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                              ? CachedNetworkImage(imageUrl: data['imageUrl'], fit: BoxFit.cover)
                              : _buildPlaceholder(70),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['productName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text("Barcode: ${data['barcodeNo'] ?? 'N/A'}",
                                style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ]),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),
                    _buildDetailRow("Category", data['category'] ?? '-'),
                    _buildDetailRow("Supplier", data['supplier'] ?? '-'),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      _buildStatusChip("Price", "RM ${price.toStringAsFixed(2)}", Colors.blue),
                      _buildStatusChip("In Stock", "$stock ${data['unit'] ?? 'pcs'}", stock <= reorderLevel ? Colors.red : Colors.green),
                    ]),
                  ]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ],
    );
  }
}