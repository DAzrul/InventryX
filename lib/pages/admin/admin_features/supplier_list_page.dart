import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// [PENTING] Import path utk navigation
import '../../Profile/User_profile_page.dart';
import '../admin_page.dart';
import '../utils/features_modal.dart'; // Modal Admin

// Import komponen reusable kau
import 'supplier_add_page.dart';
import 'supplier_edit_page.dart';
import 'supplier_delete_dialog.dart';

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  final Color primaryBlue = const Color(0xFF233E99);

  int _selectedIndex = 1;

  // --- LOGIC NAVIGATION ---
  void _onItemTapped(int index) {
    if (index == 0) {
      final user = FirebaseAuth.instance.currentUser;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => AdminPage(
            username: "Admin",
            userId: user?.uid ?? '', loggedInUsername: '',
          ),
        ),
            (Route<dynamic> route) => false,
      );
    } else if (index == 1) {
      FeaturesModal.show(context, "Admin");
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Stream<QuerySnapshot> get _supplierStream =>
      FirebaseFirestore.instance.collection("supplier").snapshots();

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
            backgroundColor: const Color(0xFFF8FAFF),

            // --- MAIN CONTENT HANDLER ---
            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildSupplierContent(), // Page Supplier
                ProfilePage(username: currentUsername, userId: uid ?? ''), // Page Profile
              ],
            ),

            // [OPTION] FAB DIBUANG UTK KEKALKAN CONSISTENCY DGN PRODUCT PAGE
            floatingActionButton: null,

            // --- FLOATING NAVBAR ---
            bottomNavigationBar: _buildFloatingNavBar(),
          );
        }
    );
  }

  // --- UI: NAVBAR ---
  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
        decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(activeIcon, size: 22, color: primaryBlue),
      ),
      label: label,
    );
  }

  // --- CONTENT ---
  Widget _buildSupplierContent() {
    return Column(
      children: [
        _buildCustomAppBar(),
        _buildSearchSection(),
        _buildTotalSuppliersCard(),
        Expanded(child: _buildSupplierListStream()),
      ],
    );
  }

  // --- [UPDATE] HEADER DENGAN BUTTON ADD KAT KANAN ---
  Widget _buildCustomAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 55, 20, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Tajuk
          const Text(
            "Suppliers Directory",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black),
          ),

          // 2. Button ADD NEW (Top Right - Konsisten dgn Product List)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierAddPage())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text("Add New", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchText = v.toLowerCase()),
          decoration: InputDecoration(hintText: "Search name or phone number...", prefixIcon: Icon(Icons.search_rounded, color: primaryBlue), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 15)),
        ),
      ),
    );
  }

  Widget _buildTotalSuppliersCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withValues(alpha: 0.8)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))]),
        child: StreamBuilder<QuerySnapshot>(
          stream: _supplierStream,
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.docs.length.toString() : "...";
            return Row(children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Active Partners", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text("$count Suppliers", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white))]), const Spacer(), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.business_rounded, color: Colors.white, size: 30))]);
          },
        ),
      ),
    );
  }

  Widget _buildSupplierListStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _supplierStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final name = (d['supplierName'] ?? '').toString().toLowerCase();
          final phone = (d['contactNo'] ?? '').toString().toLowerCase();
          return name.contains(_searchText) || phone.contains(_searchText);
        }).toList();

        if (docs.isEmpty) return Center(child: Text("No partners found", style: TextStyle(color: Colors.grey.shade400)));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final s = doc.data() as Map<String, dynamic>;
            return _SupplierCard(
              data: s, docId: doc.id, primaryColor: primaryBlue,
              onTap: () => _showSupplierDetails(context, s),
            );
          },
        );
      },
    );
  }

  void _showSupplierDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(context: context, builder: (_) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 35, backgroundColor: primaryBlue.withValues(alpha: 0.1), child: Icon(Icons.business_center_rounded, size: 35, color: primaryBlue)), const SizedBox(height: 20), Text(data['supplierName'] ?? 'Unnamed', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const Divider(height: 30), _detailRow(Icons.phone_rounded, "Phone", data['contactNo']), _detailRow(Icons.email_rounded, "Email", data['email']), _detailRow(Icons.location_on_rounded, "Address", data['address']), const SizedBox(height: 30), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => Navigator.pop(context), child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))]))));
  }

  Widget _detailRow(IconData icon, String title, String? value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: Colors.grey), const SizedBox(width: 12), Expanded(child: Text(value ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))]));
  }
}

class _SupplierCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final Color primaryColor;
  final VoidCallback onTap;

  const _SupplierCard({
    required this.data,
    required this.docId,
    required this.primaryColor,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    // Logic Responsif
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02), // Guna withOpacity kalau version lama
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- PLACEHOLDER CANTIK (Sama Style dgn Product) ---
            Container(
              width: isTablet ? 70 : isSmall ? 45 : 55,
              height: isTablet ? 70 : isSmall ? 45 : 55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: primaryColor.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.business_rounded, // Icon Supplier
                  color: primaryColor.withOpacity(0.5),
                  size: isTablet ? 30 : 24,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // TEXT INFO
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['supplierName'] ?? 'Unnamed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: isTablet ? 16 : 14,
                      color: const Color(0xFF1A1C1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_iphone_rounded, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        data['contactNo'] ?? '-',
                        style: TextStyle(
                          fontSize: isTablet ? 13 : 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  // Optional: Tambah email kalau nak
                  if (data['email'] != null && data['email'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        data['email'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                      ),
                    ),
                ],
              ),
            ),

            // ACTION BUTTONS (Edit/Delete)
            if (!isSmall)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, size: 22, color: Colors.blueGrey),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierEditPage(supplierId: docId, supplierData: data))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.redAccent),
                    onPressed: () => showDialog(context: context, builder: (_) => SupplierDeleteDialog(supplierId: docId, supplierData: data)),
                  ),
                ],
              )
            else
            // Kalau skrin kecil, pakai popup menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierEditPage(supplierId: docId, supplierData: data)));
                  } else {
                    showDialog(context: context, builder: (_) => SupplierDeleteDialog(supplierId: docId, supplierData: data));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}