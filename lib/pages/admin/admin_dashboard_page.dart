import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'user_list_page.dart';
import 'admin_features/product_list_page.dart';
import 'admin_features/supplier_list_page.dart';

class AdminDashboardPage extends StatelessWidget {
  final String loggedInUsername;
  final String userId;

  const AdminDashboardPage({super.key, required this.loggedInUsername, required this.userId});

  final Color primaryBlue = const Color(0xFF233E99);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // --- TOP SUMMARY ---
                  Row(
                    children: [
                      Expanded(child: _buildLowStockCard()),
                      const SizedBox(width: 15),
                      Expanded(child: _buildExpiringSoonCard()),
                    ],
                  ),

                  const SizedBox(height: 35),
                  const Text("Quick Action", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 15),

                  _buildLargeButton(
                    context,
                    title: "Manage Users",
                    subtitle: "Control staff & administrator access",
                    icon: Icons.people_alt_rounded,
                    page: UserListPage(loggedInUsername: loggedInUsername),
                  ),
                  const SizedBox(height: 15),
                  _buildLargeButton(
                    context,
                    title: "Inventory Products",
                    subtitle: "Stock levels and product database",
                    icon: Icons.inventory_2_rounded,
                    page: const ProductListPage(),
                  ),
                  const SizedBox(height: 15),
                  _buildLargeButton(
                    context,
                    title: "Supplier Directory",
                    subtitle: "Manage external product suppliers",
                    icon: Icons.local_shipping_rounded,
                    page: const SupplierListPage(),
                  ),

                  const SizedBox(height: 35),
                  const Text("System Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 15),

                  _buildActivityTile("Total Users", "users", Icons.person_search_rounded, Colors.blue),
                  _buildActivityTile("Total Products", "products", Icons.inventory_rounded, Colors.orange),
                  _buildActivityTile("Total Suppliers", "supplier", Icons.store_rounded, Colors.green),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGIC 1: LOW STOCK (COMPARE CURRENT VS REORDER) ---
  Widget _buildLowStockCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorCard("Low Stock");
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            return (d['currentStock'] ?? 0) <= (d['reorderLevel'] ?? 0);
          }).length;
        }
        return _buildBaseSummaryCard(label: "Low Stock", count: count, icon: Icons.arrow_downward_rounded, color: Colors.orange);
      },
    );
  }

  // --- LOGIC 2: EXPIRING SOON ---
  Widget _buildExpiringSoonCard() {
    DateTime now = DateTime.now();
    DateTime nextMonth = now.add(const Duration(days: 30));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('expiryDate', isGreaterThan: now)
          .where('expiryDate', isLessThan: nextMonth)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorCard("Expiring");
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _buildBaseSummaryCard(label: "Expiring Soon", count: count, icon: Icons.access_time_rounded, color: Colors.redAccent);
      },
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildBaseSummaryCard({required String label, required int count, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text("$count", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(25)),
      child: Column(children: [const Icon(Icons.error_outline, color: Colors.red), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 12, color: Colors.red))]),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        String name = loggedInUsername;
        String? img;
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['username'] ?? loggedInUsername;
          img = data['profilePictureUrl'];
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryBlue.withValues(alpha: 0.1), width: 2)),
                child: CircleAvatar(
                  radius: 24, backgroundColor: Colors.white,
                  backgroundImage: img != null && img.isNotEmpty ? CachedNetworkImageProvider(img) : null,
                  child: (img == null || img.isEmpty) ? Icon(Icons.person_rounded, color: primaryBlue.withValues(alpha: 0.4)) : null,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, d MMM').format(DateTime.now()), style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    Text("Hi, $name", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _buildNotificationBadge(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationBadge() {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        const Icon(Icons.notifications_none_rounded, size: 28, color: Colors.black87),
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
      ],
    );
  }

  Widget _buildLargeButton(BuildContext context, {required String title, required String subtitle, required IconData icon, required Widget page}) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: primaryBlue, borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 26),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(String title, String collection, IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 15),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              Text("$count Units", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900)),
            ],
          ),
        );
      },
    );
  }
}