import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'staff_page.dart';
import 'add_incoming_stock.dart';
import 'stock_out.dart';
import '../Features_app/barcode_scanner_page.dart';
import 'utils/staff_features_modal.dart';
import '../Profile/User_profile_page.dart';

class StockPage extends StatefulWidget {
  final String username;
  const StockPage({super.key, required this.username});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
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

  void _onItemTapped(BuildContext context, int index, String currentUsername, String uid) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => StaffPage(
            loggedInUsername: currentUsername,
            userId: uid, username: '',
          ),
        ),
            (Route<dynamic> route) => false,
      );
    } else if (index == 1) {
      StaffFeaturesModal.show(context, currentUsername, uid);
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

        final safeUid = uid ?? '';

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFF),
          resizeToAvoidBottomInset: true,
          extendBody: true,
          body: IndexedStack(
            index: _selectedIndex == 2 ? 1 : 0,
            children: [
              _buildStockHome(),
              ProfilePage(username: currentUsername, userId: safeUid),
            ],
          ),
          bottomNavigationBar: _buildFloatingNavBar(context, currentUsername, safeUid),
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
          selectedItemColor: primaryBlue,
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
        decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(activeIcon, size: 22, color: primaryBlue),
      ),
      label: label,
    );
  }

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

  Widget _buildStockHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 15),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Inventory Management", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildCombinedSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('products').snapshots(),
      builder: (context, prodSnap) => StreamBuilder<QuerySnapshot>(
        stream: _db.collection('batches').snapshots(),
        builder: (context, batchSnap) {
          int total = 0;
          int low = 0;
          int expired = 0;

          if (prodSnap.hasData) {
            total = prodSnap.data!.docs.length;

            for (var d in prodSnap.data!.docs) {
              var data = d.data() as Map<String, dynamic>;
              int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
              int reorderPoint = int.tryParse(data['reorderLevel']?.toString() ?? '10') ?? 10;

              if (stock <= reorderPoint) {
                low++;
              }
            }
          }

          if (batchSnap.hasData) {
            DateTime now = DateTime.now();
            for (var d in batchSnap.data!.docs) {
              var b = d.data() as Map<String, dynamic>;
              Timestamp? expTimestamp = b['expiryDate'] as Timestamp?;
              int qty = int.tryParse(b['currentQuantity']?.toString() ?? '0') ?? 0;

              if (expTimestamp != null && qty > 0) {
                if (expTimestamp.toDate().isBefore(now)) {
                  expired++;
                }
              }
            }
          }

          return Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryItem(value: '$total', label: 'Total SKUs', color: primaryBlue),
                _SummaryItem(value: '$low', label: 'Low Stock', color: Colors.orange),
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
        decoration: InputDecoration(hintText: "Search products (Name/SKU)...", border: InputBorder.none, prefixIcon: Icon(Icons.search, color: Colors.grey.shade400), suffixIcon: IconButton(icon: Icon(Icons.qr_code_scanner, color: primaryBlue), onPressed: _scanBarcode)),
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

  // --- [FIXED] LIST BUILDER WITH SAFE BARCODE PARSING ---
  Widget _buildProductStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        List<QueryDocumentSnapshot> docs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;

          final name = (d['productName'] ?? '').toString().toLowerCase();
          final barcode = (d['barcodeNo'] ?? '').toString().toLowerCase(); // Safe conversion
          final query = searchQuery.toLowerCase();

          bool catMatch = (selectedCategory == 'All' || d['category'] == selectedCategory);
          bool searchMatch = name.contains(query) || barcode.contains(query);

          return catMatch && searchMatch;
        }).toList();

        docs.sort((a, b) {
          int stockA = int.tryParse((a.data() as Map<String, dynamic>)['currentStock']?.toString() ?? '0') ?? 0;
          int stockB = int.tryParse((b.data() as Map<String, dynamic>)['currentStock']?.toString() ?? '0') ?? 0;
          return stockB.compareTo(stockA);
        });

        final screenWidth = MediaQuery.of(context).size.width;
        final isSmall = screenWidth < 360;
        final isTablet = screenWidth >= 600;
        final double imgSize = isTablet ? 70 : isSmall ? 45 : 55;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
            int reorderPoint = int.tryParse(data['reorderLevel']?.toString() ?? '10') ?? 10;

            double price = double.tryParse(data['price']?.toString() ?? '0.0') ?? 0.0;

            // ✅ [FIX UTAMA] Pastikan barcode sentiasa ditukar ke String
            String barcode = data['barcodeNo']?.toString() ?? '-';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
              ),
              child: InkWell(
                onTap: () => _showProductDetails(data, docs[index].id),
                child: Row(
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
                            data['productName'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "SN: $barcode",
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "RM ${price.toStringAsFixed(2)}",
                                style: TextStyle(color: primaryBlue.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                            '$stock',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: stock <= reorderPoint ? Colors.red : primaryBlue
                            )
                        ),
                        Text(
                          data['unit'] ?? 'pcs',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                        )
                      ],
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

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: primaryBlue.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: primaryBlue.withOpacity(0.3),
          size: size * 0.5,
        ),
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> data, String productId) {
    int stock = int.tryParse(data['currentStock']?.toString() ?? '0') ?? 0;
    int reorderPoint = int.tryParse(data['reorderLevel']?.toString() ?? '10') ?? 10;
    double price = double.tryParse(data['price']?.toString() ?? '0.0') ?? 0.0;
    final double imgSize = 75;

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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: (data['imageUrl'] != null && data['imageUrl'].isNotEmpty)
                          ? CachedNetworkImage(imageUrl: data['imageUrl'], width: imgSize, height: imgSize, fit: BoxFit.cover)
                          : _buildPlaceholder(imgSize),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data['productName'] ?? 'Unknown', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      Text("SKU/Barcode: ${data['barcodeNo'] ?? '-'}", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    ]))
                  ]),
                  const SizedBox(height: 30),
                  Row(children: [
                    _infoBox("Status", stock <= reorderPoint ? "Low Stock" : "Healthy", stock <= reorderPoint ? Colors.orange : Colors.green),
                    const SizedBox(width: 10),
                    _infoBox("Price", "RM ${price.toStringAsFixed(2)}", primaryBlue),
                    const SizedBox(width: 10),
                    _infoBox("Supplier", data['supplier'] ?? 'N/A', Colors.grey.shade700),
                  ]),
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

  Widget _infoBox(String t, String v, Color c) {
    return Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: c.withOpacity(0.1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontSize: 10, color: c.withOpacity(0.6), fontWeight: FontWeight.w800)), Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c))])));
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