import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/menu_container.dart';
import 'widgets/dashboard_card.dart';
import 'user_list_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final String loggedInUsername;
  final String userId;
  final bool showFeatureGrid;
  // [UBAH] Callback ini kini menerima Index (int) untuk tukar tab
  final Function(int) onTabChange;

  const AdminDashboardPage({
    super.key,
    required this.loggedInUsername,
    required this.userId,
    required this.showFeatureGrid,
    required this.onTabChange, // [WAJIB]
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int totalUsers = 0;
  bool isLoading = true;

  // Nilai statik
  final int productTypes = 31;
  final int totalSuppliers = 19;
  final double userGrowth = 3.2;
  final double productGrowth = 5.1;
  final double supplierGrowth = 5.1;

  @override
  void initState() {
    super.initState();
    fetchTotalUsers();
  }

  Future<void> fetchTotalUsers() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection("users").get();
      if (mounted) {
        setState(() {
          totalUsers = snapshot.docs.length;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // [PENYELESAIAN] Fungsi ini Tunggu (await) UserList ditutup
  void _goToUserList(String currentUsername) async {
    // 1. Buka User List dan TUNGGU result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserListPage(
          loggedInUsername: currentUsername,
        ),
      ),
    );

    // 2. Jika result adalah nombor (0 = Home, 2 = Profile), beritahu Parent
    if (result != null && result is int) {
      widget.onTabChange(result);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  DashboardCard(
                    title: "Total Users",
                    value: isLoading ? '...' : totalUsers.toString(),
                    growth: "+${userGrowth.toStringAsFixed(1)}% vs last week",
                    icon: Icons.people_alt,
                    // Panggil fungsi navigasi yang telah dibaiki
                    onViewPressed: () => _goToUserList(displayUsername),
                  ),
                  const SizedBox(height: 20),

                  DashboardCard(
                    title: "Product Types",
                    value: productTypes.toString(),
                    growth: "+${productGrowth.toStringAsFixed(1)}% vs last month",
                    icon: Icons.inventory_2,
                    onViewPressed: () { /* Tindakan ke Product Page */ },
                  ),
                  const SizedBox(height: 20),

                  DashboardCard(
                    title: "Supplier",
                    value: totalSuppliers.toString(),
                    growth: "+${supplierGrowth.toStringAsFixed(1)}% vs last month",
                    icon: Icons.local_shipping_outlined,
                    onViewPressed: () { /* Tindakan ke Supplier Page */ },
                  ),
                ],
              ),
            ),
          );
        }
    );
  }
}