import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

// [NOTE] Pastikan path import ni betul ikut struktur folder kau mat!
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
  int _selectedIndex = 1; // Default kat Features (Index 1)
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

  // --- LOGIC: NAVIGATION (HOME BACK TO DASHBOARD) ---
  void _onItemTapped(int index) {
    if (index == 0) {
      // BALIK TERUS KE DASHBOARD UTAMA
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (index == 1) {
      StaffFeaturesModal.show(context);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
    if (scanned != null) {
      setState(() {
        searchQuery = scanned;
        _searchController.text = scanned;
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
          // [FIX] Kalau kau nak content tolak ke atas bila keyboard keluar, set ni TRUE
          resizeToAvoidBottomInset: true,
          extendBody: true,
          body: IndexedStack(
            index: _selectedIndex == 2 ? 1 : 0,
            children: [
              _buildStockHome(),
              ProfilePage(username: currentUsername, userId: '',),
            ],
          ),
          bottomNavigationBar: _buildFloatingNavBar(),
        );
      },
    );
  }

  // --- UI: STOCK HOME (TAB 0) ---
  Widget _buildStockHome() {
    return Column(
      children: [
        _buildStockHeader(),
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

  // --- UI: FLOATING NAVBAR ---
  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
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
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey.shade400,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
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
        decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(activeIcon, size: 22, color: primaryBlue),
      ),
      label: label,
    );
  }

  // --- UI: CUSTOM APP BAR ---
  Widget _buildStockHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 15),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
          const Text("Inventory Management", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // --- UI: SUMMARY CARD ---
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)]),
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
      onPressed: onTap, icon: Icon(icon, size: 18, color: Colors.white), label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(hintText: "Search products...", border: InputBorder.none, prefixIcon: Icon(Icons.search, color: Colors.grey.shade400), suffixIcon: IconButton(icon: Icon(Icons.qr_code_scanner, color: primaryBlue), onPressed: _scanBarcode)),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['All', 'FOOD', 'BEVERAGES', 'PERSONAL CARE'].map((cat) {
          final isSel = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat), selected: isSel, onSelected: (_) => setState(() => selectedCategory = cat),
              selectedColor: primaryBlue, backgroundColor: Colors.white, labelStyle: TextStyle(color: isSel ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          return (selectedCategory == 'All' || d['category'] == selectedCategory) && name.contains(searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          // [FIX] Tambah padding bawah sekurang-kurangnya 100-120 mat!
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
              child: ListTile(
                onTap: () => _showProductDetails(data, docs[index].id),
                leading: _buildProductImage(data['imageUrl'], size: 50),
                title: Text(data['productName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: Text('$stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: stock <= 10 ? Colors.red : primaryBlue)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductImage(String? url, {double size = 50}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: const Color(0xFFF0F2F6), borderRadius: BorderRadius.circular(15)),
      child: (url != null && url.isNotEmpty) ? ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)) : Icon(Icons.inventory_2_rounded, color: primaryBlue, size: size * 0.5),
    );
  }

  // --- REPAIRED MODAL DETAILS ---
  void _showProductDetails(Map<String, dynamic> data, String productId) {
    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(children: [
                    _buildProductImage(data['imageUrl'], size: 80),
                    const SizedBox(width: 20),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data['productName'] ?? 'Unknown', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      Text("SKU: ${data['barcodeNo'] ?? '-'}", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ]))
                  ]),
                  const SizedBox(height: 30),
                  _buildQuickStats(data, stock),
                  const SizedBox(height: 35),
                  const Text("Active Stock Batches", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 15),
                  _buildBatchStream(productId, data['unit'] ?? 'pcs'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> data, int stock) {
    Color c = stock <= 10 ? Colors.orange : Colors.green;
    return Row(children: [
      _infoBox("Status", stock <= 10 ? "Low Stock" : "Healthy", c),
      const SizedBox(width: 12),
      _infoBox("Supplier", data['supplier'] ?? 'N/A', primaryBlue),
    ]);
  }

  Widget _infoBox(String t, String v, Color c) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: c.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: TextStyle(fontSize: 10, color: c.withOpacity(0.6), fontWeight: FontWeight.w800)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c)),
      ]),
    ));
  }

  Widget _buildBatchStream(String pid, String unit) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('batches').where('productId', isEqualTo: pid).where('currentQuantity', isGreaterThan: 0).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No active batches.", style: TextStyle(color: Colors.grey))));
        return Column(children: docs.map((doc) {
          final b = doc.data() as Map<String, dynamic>;
          final exp = b['expiryDate'] != null ? (b['expiryDate'] as Timestamp).toDate() : null;
          return Container(
            margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)]),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Batch #${b['batchNumber'] ?? '-'}", style: const TextStyle(fontWeight: FontWeight.w800)),
                if (exp != null) Text("Exp: ${DateFormat('dd/MM/yyyy').format(exp)}", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
              Text("${b['currentQuantity']} $unit", style: TextStyle(fontWeight: FontWeight.w900, color: primaryBlue)),
            ]),
          );
        }).toList());
      },
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
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}