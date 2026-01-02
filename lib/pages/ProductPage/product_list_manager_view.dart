import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [PENTING] Import manager_page (Bapak Page)
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
  int _selectedIndex = 1; // Default 1 sebab kita kat features/product
  String _searchText = '';
  String _selectedCategory = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  final Color primaryColor = const Color(0xFF203288);
  final List<String> _categories = ['ALL', 'FOOD', 'BEVERAGES', 'PERSONAL CARE'];

  // --- LOGIC NUCLEAR: RESET APP ---
  void _onItemTapped(int index) {
    if (index == 0) {
      // 1. Dapatkan user semasa
      final user = FirebaseAuth.instance.currentUser;

      // 2. BUNUH SEMUA PAGE, LOAD STAFF DASHBOARD BARU
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ManagerPage(
            loggedInUsername: "Manager", // Placeholder, stream akan handle
            userId: user?.uid ?? '', username: '',
          ),
        ),
            (Route<dynamic> route) => false,
      );

    } else if (index == 1) {
      ManagerFeaturesModal.show(context);
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
          String currentUsername = "User";
          if (snapshot.hasData && snapshot.data!.exists) {
            var d = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = d['username'] ?? "User";
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF6F8FB),
            extendBody: true,
            resizeToAvoidBottomInset: false,

            // Panggil function navbar yang dah di-design semula
            bottomNavigationBar: _buildFloatingNavBar(),

            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildInventoryHome(),
                ProfilePage(username: currentUsername, userId: uid ?? ''),
              ],
            ),
          );
        }
    );
  }

  // --- DESIGN NAVBAR: SEBIJI MACAM DASHBOARD ---
  Widget _buildFloatingNavBar() {
    return Container(
      // [FIX] Margin mesti sama dengan Dashboard (12 bottom)
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade400,

          // [FIX PENTING] Ini property yang buat dia nampak "sama" dgn dashboard
          showSelectedLabels: true,
          showUnselectedLabels: false, // Label hilang kalau tak select (clean look)
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
          color: primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(activeIcon, size: 22, color: primaryColor),
      ),
      label: label,
    );
  }

  // --- UI Components Lain (Tak Berubah) ---
  Widget _buildInventoryHome() {
    return Column(children: [_buildTopHeader(), _buildCategoryFilters(), _buildProductList()]);
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Products", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Container(decoration: BoxDecoration(color: const Color(0xFFF5F7FB), borderRadius: BorderRadius.circular(18)), child: TextField(controller: _searchController, onChanged: (v) => setState(() => _searchText = v.trim().toLowerCase()), decoration: InputDecoration(hintText: "Search items...", prefixIcon: Icon(Icons.search_rounded, color: primaryColor), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 15))))),
          const SizedBox(width: 12),
          GestureDetector(onTap: () async { final scanned = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage())); if (scanned != null) setState(() { _searchText = scanned; _searchController.text = scanned; }); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white))),
        ]),
      ]),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(height: 60, margin: const EdgeInsets.symmetric(vertical: 10), child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: _categories.length, itemBuilder: (context, index) { final cat = _categories[index]; final isSel = _selectedCategory == cat; return GestureDetector(onTap: () => setState(() => _selectedCategory = cat), child: Container(margin: const EdgeInsets.only(right: 10, top: 10, bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: isSel ? primaryColor : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: isSel ? Colors.transparent : Colors.grey.shade200)), child: Center(child: Text(cat, style: TextStyle(color: isSel ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))))); }));
  }

  Widget _buildProductList() {
    return Expanded(child: StreamBuilder<QuerySnapshot>(stream: (_selectedCategory == 'ALL') ? FirebaseFirestore.instance.collection("products").snapshots() : FirebaseFirestore.instance.collection("products").where('category', isEqualTo: _selectedCategory).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const Center(child: CircularProgressIndicator()); final docs = snapshot.data!.docs.where((d) => d['productName'].toString().toLowerCase().contains(_searchText)).toList(); return ListView.builder(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), physics: const BouncingScrollPhysics(), itemCount: docs.length, itemBuilder: (context, index) { final data = docs[index].data() as Map<String, dynamic>; return _buildProductCard(data); }); }));
  }

  Widget _buildProductCard(Map<String, dynamic> data) {
    return Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]), child: Row(children: [Container(width: 70, height: 70, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: Colors.grey[100]), child: (data['imageUrl'] != null && data['imageUrl'] != '') ? ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: data['imageUrl'], fit: BoxFit.cover)) : Icon(Icons.inventory_2_rounded, color: primaryColor.withValues(alpha: 0.2))), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['productName'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text("${data['category']} • Stock: ${data['currentStock']}", style: TextStyle(fontSize: 11, color: Colors.grey[500]))])), const Icon(Icons.chevron_right_rounded, color: Colors.grey)]));
  }
}