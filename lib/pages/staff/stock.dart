import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import path mat, pastikan betul!
import 'add_incoming_stock.dart';
import 'stock_out.dart';
import '../Features_app/barcode_scanner_page.dart';
import '../staff/utils/staff_features_modal.dart';
import '../Profile/User_profile_page.dart';

class StockPage extends StatefulWidget {
  final String username;
  const StockPage({super.key, required this.username});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  // Index 0: Stock Home, Index 1: Features (Modal), Index 2: Profile
  int _selectedIndex = 1;
  String selectedCategory = 'All';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Color primaryBlue = const Color(0xFF1E3A8A);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIC: NAVIGATION TAPPED (GOD MODE) ---
  void _onItemTapped(int index) {
    if (index == 0) {
      // [FIX] CLICK HOME -> BALIK TERUS DASHBOARD STAFF
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (index == 1) {
      StaffFeaturesModal.show(context);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _scanBarcode() async {
    final scannedResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (scannedResult != null && scannedResult.isNotEmpty) {
      setState(() {
        searchQuery = scannedResult;
        _searchController.text = scannedResult;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          String currentUsername = widget.username;
          if (snapshot.hasData && snapshot.data!.exists) {
            var d = snapshot.data!.data() as Map<String, dynamic>;
            currentUsername = d['username'] ?? widget.username;
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFF),
            extendBody: true, // Biar floating nav nampak kacak

            // --- MAIN CONTENT (STOCK HOME VS PROFILE) ---
            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildStockHome(),
                ProfilePage(username: currentUsername),
              ],
            ),

            bottomNavigationBar: _buildFloatingNavBar(),
          );
        }
    );
  }

  // --- UI: STOCK MAIN CONTENT (TAB 0) ---
  Widget _buildStockHome() {
    return Column(
      children: [
        _buildStockHeader(), // AppBar custom dlm ni mat
        _buildCombinedSummary(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _buildActionButtons(),
              const SizedBox(height: 15),
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildCategoryFilter(),
            ],
          ),
        ),
        Expanded(child: _buildProductStream()),
      ],
    );
  }

  Widget _buildStockHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 15),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Text("Inventory Management", style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(width: 40), // Spacer sbb leading ada icon
        ],
      ),
    );
  }

  // --- UI: FLOATING NAVBAR ---
  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey.shade400,
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
        decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(activeIcon, size: 22, color: primaryBlue),
      ),
      label: label,
    );
  }

  // --- KEKALKAN SEMUA WIDGET ASAL KAU (SUMMARY, ACTION BTN, SEARCH, DLL) ---
  // ... (Sila copy semula widget _buildCombinedSummary, _buildActionButtons, dll dari kod kau)
  // Aku skip dlm ni sbb nak jimat ruang mat.

  Widget _buildCombinedSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('products').snapshots(),
      builder: (context, prodSnap) => StreamBuilder<QuerySnapshot>(
        stream: _db.collection('batches').snapshots(),
        builder: (context, batchSnap) {
          int total = prodSnap.hasData ? prodSnap.data!.docs.length : 0;
          int low = 0;
          int expired = 0;

          if (prodSnap.hasData) {
            for (var d in prodSnap.data!.docs) {
              int q = int.tryParse(d['currentStock']?.toString() ?? '0') ?? 0;
              if (q > 0 && q <= 10) low++;
            }
          }

          if (batchSnap.hasData) {
            DateTime now = DateTime.now();
            for (var d in batchSnap.data!.docs) {
              var b = d.data() as Map<String, dynamic>;
              if (b['expiryDate'] != null && (b['currentQuantity'] ?? 0) > 0) {
                if ((b['expiryDate'] as Timestamp).toDate().isBefore(now)) expired++;
              }
            }
          }

          return Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryItem(value: '$total', label: 'Total SKUs', color: primaryBlue),
                _SummaryItem(value: '$low', label: 'Low Stock', color: Colors.orange),
                _SummaryItem(value: '$expired', label: 'Expired', color: Colors.red),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(child: _actionBtn("Stock In", Icons.add_box_rounded, primaryBlue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddIncomingStockPage(username: widget.username))))),
      const SizedBox(width: 12),
      Expanded(child: _actionBtn("Stock Out", Icons.indeterminate_check_box_rounded, Colors.red.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockOutPage())))),
    ]);
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: const InputDecoration(hintText: "Search products...", border: InputBorder.none, hintStyle: TextStyle(fontSize: 14)),
            ),
          ),
          IconButton(icon: Icon(Icons.qr_code_scanner_rounded, color: primaryBlue), onPressed: _scanBarcode),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: ['All', 'FOOD', 'BEVERAGES', 'PERSONAL CARE'].map((cat) {
          final isSel = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSel,
              onSelected: (_) => setState(() => selectedCategory = cat),
              selectedColor: primaryBlue,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(color: isSel ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSel ? primaryBlue : Colors.grey.shade100)),
              elevation: 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final name = (d['productName'] ?? '').toString().toLowerCase();
          final barcode = (d['barcodeNo'] ?? '').toString().toLowerCase();
          return (selectedCategory == 'All' || d['category'] == selectedCategory) &&
              (name.contains(searchQuery.toLowerCase()) || barcode.contains(searchQuery.toLowerCase()));
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
            return _buildProductCard(data, docs[index].id, stock);
          },
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> data, String id, int stock) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
      child: ListTile(
        onTap: () => _showProductDetails(data, id),
        contentPadding: const EdgeInsets.all(12),
        leading: _buildProductImage(data['imageUrl'], size: 55),
        title: Text(data['productName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        trailing: Text('$stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: stock <= 10 ? Colors.red : primaryBlue)),
      ),
    );
  }

  Widget _buildProductImage(String? url, {double size = 50}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: const Color(0xFFF0F2F6), borderRadius: BorderRadius.circular(15)),
      child: (url != null && url.isNotEmpty)
          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(url, fit: BoxFit.cover))
          : Icon(Icons.inventory_2_rounded, color: primaryBlue, size: size * 0.5),
    );
  }

  // --- MODAL DETAILS (KEKALKAN LOGIC KAU) ---
  void _showProductDetails(Map<String, dynamic> data, String productId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const Padding(padding: EdgeInsets.all(20), child: Text("Product Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            // Sini kau masukkan logic batch stream kau mat
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value, label; final Color color;
  const _SummaryItem({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}