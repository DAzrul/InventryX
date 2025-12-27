import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierListPageView extends StatefulWidget {
  const SupplierListPageView({super.key});

  @override
  State<SupplierListPageView> createState() => _SupplierListPageViewState();
}

class _SupplierListPageViewState extends State<SupplierListPageView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  int _currentIndex = 0; // 0 for Home, 1 for Profile

  final Color primaryBlue = const Color(0xFF233E99);
  final Color bgGray = const Color(0xFFF8F9FD);

  Stream<QuerySnapshot> get _supplierStream =>
      FirebaseFirestore.instance.collection("supplier").snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGray,
      body: Column(
        children: [
          _buildTopHeader(),
          _buildSummaryCard(),
          _buildSupplierList(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- MODERN HEADER ---
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Suppliers", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(color: bgGray, borderRadius: BorderRadius.circular(18)),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchText = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search name or contact...",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: primaryBlue, size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DASHBOARD SUMMARY CARD ---
  Widget _buildSummaryCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _supplierStream,
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryBlue, primaryBlue.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$count", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                  const Text("Active Suppliers", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- SUPPLIER LIST ---
  Widget _buildSupplierList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _supplierStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Fucking Error!"));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: primaryBlue));

          final docs = snapshot.data!.docs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final name = (d['supplierName'] ?? '').toString().toLowerCase();
            final phone = (d['contactNo'] ?? '').toString().toLowerCase();
            return name.contains(_searchText) || phone.contains(_searchText);
          }).toList();

          if (docs.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final s = docs[index].data() as Map<String, dynamic>;
              return _buildSupplierCard(s);
            },
          );
        },
      ),
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => _showSupplierDetails(context, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bgGray, borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.store_rounded, color: primaryBlue, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['supplierName'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(data['contactNo'] ?? '-', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  // --- DETAILS MODAL ---
  void _showSupplierDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: bgGray, shape: BoxShape.circle),
                child: Icon(Icons.store_rounded, color: primaryBlue, size: 60),
              ),
              const SizedBox(height: 20),
              Text(data['supplierName'] ?? '-', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 35),
              _detailRow("Contact No", data['contactNo'], Icons.phone_android_rounded),
              _detailRow("Email", data['email'], Icons.email_rounded),
              _detailRow("Address", data['address'], Icons.location_on_rounded),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CLOSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryBlue, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700)),
                Text("${value ?? '-'}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Text("No suppliers found mat!", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)));
  }

  // --- SIMPLIFIED BOTTOM NAV (2 ITEMS) ---
  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(Icons.home_rounded, "Home", 0),
          _navItem(Icons.person_rounded, "Profile", 1),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSel = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSel ? primaryBlue : Colors.grey[400], size: 26),
            if (isSel) const SizedBox(width: 8),
            if (isSel) Text(label, style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}