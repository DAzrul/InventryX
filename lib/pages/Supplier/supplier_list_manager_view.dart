import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../manager/manager_page.dart';
import '../manager/utils/manager_features_modal.dart';
import '../Profile/User_profile_page.dart';

class SupplierListManagerView extends StatefulWidget {
  const SupplierListManagerView({super.key});
  @override
  State<SupplierListManagerView> createState() => _SupplierListPageViewState();
}

class _SupplierListPageViewState extends State<SupplierListManagerView> {
  int _selectedIndex = 1;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  final Color primaryBlue = const Color(0xFF233E99);
  final Color bgGray = const Color(0xFFF8F9FD);

  // [FIX] Terima context, username, uid
  void _onItemTapped(BuildContext context, int index, String currentUsername, String uid) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ManagerPage(
            loggedInUsername: currentUsername,
            userId: uid, username: '',
          ),
        ), (Route<dynamic> route) => false,
      );
    } else if (index == 1) {
      // [FIX] Hantar 3 Data
      ManagerFeaturesModal.show(context, currentUsername, uid);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Stream<QuerySnapshot> get _supplierStream => FirebaseFirestore.instance.collection("supplier").snapshots();

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
            backgroundColor: bgGray,
            extendBody: true,
            resizeToAvoidBottomInset: false,
            body: IndexedStack(
              index: _selectedIndex == 2 ? 1 : 0,
              children: [
                _buildSupplierHome(),
                ProfilePage(username: currentUsername, userId: safeUid),
              ],
            ),
            bottomNavigationBar: _buildFloatingNavBar(context, currentUsername, safeUid),
          );
        }
    );
  }

  Widget _buildFloatingNavBar(BuildContext context, String username, String uid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      height: 62,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => _onItemTapped(context, index, username, uid),
          backgroundColor: Colors.white,
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true, showUnselectedLabels: false, type: BottomNavigationBarType.fixed, elevation: 0,
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
    return BottomNavigationBarItem(icon: Icon(inactiveIcon, size: 22), activeIcon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: Icon(activeIcon, size: 22, color: primaryBlue)), label: label);
  }

  // --- UI Components Lain ---
  Widget _buildSupplierHome() { return Column(children: [_buildTopHeader(), _buildSummaryCard(), _buildSupplierList()]); }

  Widget _buildTopHeader() {
    return Container(padding: const EdgeInsets.fromLTRB(24, 60, 24, 20), decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Suppliers", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)), const SizedBox(height: 20), Container(decoration: BoxDecoration(color: bgGray, borderRadius: BorderRadius.circular(18)), child: TextField(controller: _searchController, onChanged: (v) => setState(() => _searchText = v.toLowerCase()), decoration: InputDecoration(hintText: "Search name or contact...", hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14), prefixIcon: Icon(Icons.search_rounded, color: primaryBlue, size: 22), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 15))))]));
  }

  Widget _buildSummaryCard() {
    return StreamBuilder<QuerySnapshot>(stream: _supplierStream, builder: (context, snapshot) { int count = snapshot.hasData ? snapshot.data!.docs.length : 0; return Container(margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withOpacity(0.8)]), borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28)), const SizedBox(width: 20), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("$count", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)), const Text("Active Suppliers", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12))])])); });
  }

  Widget _buildSupplierList() {
    return Expanded(child: StreamBuilder<QuerySnapshot>(stream: _supplierStream, builder: (context, snapshot) { if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: primaryBlue)); final docs = snapshot.data!.docs.where((doc) { final d = doc.data() as Map<String, dynamic>; final name = (d['supplierName'] ?? '').toString().toLowerCase(); final phone = (d['contactNo'] ?? '').toString().toLowerCase(); return name.contains(_searchText) || phone.contains(_searchText); }).toList(); if (docs.isEmpty) return _buildEmptyState(); return ListView.builder(padding: const EdgeInsets.fromLTRB(24, 0, 24, 100), physics: const BouncingScrollPhysics(), itemCount: docs.length, itemBuilder: (context, index) { final s = docs[index].data() as Map<String, dynamic>; return _buildSupplierCard(s); }); }));
  }

  // --- [KEMASKINI UTAMA] KAD SUPPLIER RESPONSIVE (SAMA PRODUCT) ---
  Widget _buildSupplierCard(Map<String, dynamic> data) {
    // Logic Responsif: Sama sebiji dengan Product List
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final isTablet = screenWidth >= 600;
    final double imgSize = isTablet ? 70 : isSmall ? 45 : 55; // Saiz standard 55 (bukan 70 terus)

    return GestureDetector(
        onTap: () => _showSupplierDetails(context, data),
        child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
            ),
            child: Row(
                children: [
                  // --- KOTAK IKON (Dynamic Size) ---
                  Container(
                      width: imgSize,
                      height: imgSize,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: primaryBlue.withOpacity(0.1), width: 1.5)
                      ),
                      child: Center(
                          child: Icon(
                              Icons.business_rounded,
                              color: primaryBlue.withOpacity(0.3),
                              size: imgSize * 0.5 // Icon separuh dari kotak
                          )
                      )
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                data['supplierName'] ?? '-',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: isTablet ? 16 : 14, color: const Color(0xFF1A1C1E)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis
                            ),
                            const SizedBox(height: 4),
                            Row(
                                children: [
                                  Icon(Icons.phone_iphone_rounded, size: 12, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(data['contactNo'] ?? '-', style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600))
                                ]
                            )
                          ]
                      )
                  ),

                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300])
                ]
            )
        )
    );
  }

  void _showSupplierDetails(BuildContext context, Map<String, dynamic> data) { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => Container(height: MediaQuery.of(context).size.height * 0.7, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))), child: SingleChildScrollView(padding: const EdgeInsets.all(30), child: Column(children: [Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))), const SizedBox(height: 30), Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: bgGray, shape: BoxShape.circle), child: Icon(Icons.store_rounded, color: primaryBlue, size: 60)), const SizedBox(height: 20), Text(data['supplierName'] ?? '-', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 35), _detailRow("Contact No", data['contactNo'], Icons.phone_android_rounded), _detailRow("Email", data['email'], Icons.email_rounded), _detailRow("Address", data['address'], Icons.location_on_rounded), const SizedBox(height: 40), SizedBox(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: () => Navigator.pop(context), child: const Text("CLOSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))))])))); }
  Widget _detailRow(String label, dynamic value, IconData icon) { return Padding(padding: const EdgeInsets.only(bottom: 25), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: primaryBlue, size: 22), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700)), Text("${value ?? '-'}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))]))])); }
  Widget _buildEmptyState() { return Center(child: Text("No suppliers found!", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold))); }
}