import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_features/supplier_list_page.dart';
import 'widgets/menu_container.dart';
import 'widgets/dashboard_card.dart';
import 'user_list_page.dart';
import 'admin_features/product_list_page.dart';


class AdminDashboardPage extends StatefulWidget {
  final String loggedInUsername;
  final String userId;
  final bool showFeatureGrid;
  final Function(int) onTabChange;

  const AdminDashboardPage({
    super.key,
    required this.loggedInUsername,
    required this.userId,
    required this.showFeatureGrid,
    required this.onTabChange,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  // Tak payah variable state manual dah. Kita biar Stream buat kerja.
  // Nilai statik untuk growth (Kalau nak dynamic kena kira manual, tapi ni dummy dulu ok la)
  final double userGrowth = 3.2;
  final double productGrowth = 5.1;
  final double supplierGrowth = 5.1;

  // Fungsi navigasi kekal sama
  void _goToUserList(String currentUsername) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserListPage(
          loggedInUsername: currentUsername,
        ),
      ),
    );

    if (result != null && result is int) {
      widget.onTabChange(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stream 1: Check Profile Admin (untuk update nama/gambar sendiri)
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {

          String displayUsername = widget.loggedInUsername;

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            displayUsername = data['username'] ?? widget.loggedInUsername;
          }

          return MenuContainer(
            loggedInUsername: displayUsername,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [

                  // --- KAD 1: TOTAL USERS (FIXED - GUNA STREAM) ---
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("users").snapshots(),
                    builder: (context, snapshot) {
                      // Kalau tengah loading, tunjuk "..." atau "0"
                      final totalUsers = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      final isLoading = snapshot.connectionState == ConnectionState.waiting;

                      return DashboardCard(
                        title: "Total Users",
                        value: isLoading ? "..." : totalUsers.toString(),
                        growth: "+${userGrowth.toStringAsFixed(1)}% vs last week",
                        icon: Icons.people_alt,
                        onViewPressed: () => _goToUserList(displayUsername),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // --- KAD 2: TOTAL PRODUCTS ---
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("products").snapshots(),
                    builder: (context, snapshot) {
                      final totalProducts = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return DashboardCard(
                        title: "Total Products",
                        value: totalProducts.toString(),
                        growth: "+${productGrowth.toStringAsFixed(1)}% vs last month",
                        icon: Icons.inventory_2,
                        onViewPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProductListPage()),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // --- KAD 3: TOTAL SUPPLIERS ---
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("supplier").snapshots(),
                    builder: (context, snapshot) {
                      final totalSuppliers = snapshot.hasData ? snapshot.data!.docs.length : 0;

                      return DashboardCard(
                        title: "Total Suppliers",
                        value: totalSuppliers.toString(),
                        growth: "+${supplierGrowth.toStringAsFixed(1)}% vs last month", // Aku fix sikit text dia
                        icon: Icons.store,
                        onViewPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SupplierListPage()),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }
    );
  }
}