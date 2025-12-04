// File: lib/pages/admin/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import widgets yang telah dipisahkan
import 'widgets/menu_container.dart';
import 'widgets/dashboard_card.dart';
import 'features_grid.dart'; // Asumsi fitur grid di admin/features_grid.dart

class AdminDashboardPage extends StatefulWidget {
  final String loggedInUsername;
  final bool showFeatureGrid;
  final VoidCallback onNavigateToUserList;

  const AdminDashboardPage({
    super.key,
    required this.loggedInUsername,
    required this.showFeatureGrid,
    required this.onNavigateToUserList,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int totalUsers = 0;
  bool isLoading = true;

  // Nilai berdasarkan UI Gambar
  final int productTypes = 31;
  final int totalSuppliers = 19;
  final double userGrowth = 3.2;
  final double productGrowth = 5.1;
  final double supplierGrowth = 5.1;
  final String salesValue = "22,109";
  final String salesGrowth = "Last 3 days";

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
      if (mounted) {
        setState(() {
          totalUsers = 0;
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuContainer(
      loggedInUsername: widget.loggedInUsername,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            // Card 1: Total Users
            DashboardCard(
              title: "Total Users",
              value: isLoading ? '...' : totalUsers.toString(),
              growth: "+${userGrowth.toStringAsFixed(1)}% vs last week",
              icon: Icons.people_alt,
              onViewPressed: widget.onNavigateToUserList,
            ),
            const SizedBox(height: 20),

            // Card 2: Product Types
            DashboardCard(
              title: "Product Types",
              value: productTypes.toString(),
              growth: "+${productGrowth.toStringAsFixed(1)}% vs last month",
              icon: Icons.inventory_2,
              onViewPressed: () { /* Tindakan ke Product Page */ },
            ),
            const SizedBox(height: 20),

            // Card 3: Supplier
            DashboardCard(
              title: "Supplier",
              value: totalSuppliers.toString(),
              growth: "+${supplierGrowth.toStringAsFixed(1)}% vs last month",
              icon: Icons.local_shipping_outlined,
              onViewPressed: () { /* Tindakan ke Supplier Page */ },
            ),

            const SizedBox(height: 20),

            // KONDISIONAL: Paparkan Feature Grid atau Sales Card
            if (widget.showFeatureGrid)
              FeaturesGrid(loggedInUsername: widget.loggedInUsername)
            else
              DashboardCard(
                title: "Sales",
                value: "\$${salesValue}",
                growth: salesGrowth,
                icon: Icons.monetization_on_outlined,
                onViewPressed: () {
                  // Tindakan ke Sales Page
                },
              ),
          ],
        ),
      ),
    );
  }
}